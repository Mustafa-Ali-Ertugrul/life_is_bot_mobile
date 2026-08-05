// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../core/api_client.dart';
import '../core/app_navigator.dart';
import '../models/medication.dart';
import '../models/habit.dart';

/// Uygulama kapalıyken bildirim aksiyonlarını işler (background isolate)
@pragma('vm:entry-point')
void backgroundNotificationHandler(NotificationResponse response) async {
  await NotificationService.handleAction(response, allowNavigation: false);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Exposed for foreground service channel creation.
  static FlutterLocalNotificationsPlugin get localNotifications =>
      _notifications;

  static bool _initialized = false;

  /// Bildirim servisini başlat
  static Future<void> init() async {
    if (_initialized) return;

    // Timezone başlat
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) =>
          handleAction(response, allowNavigation: true),
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );

    // Android 13+ için bildirim kanalı oluştur
    await _createNotificationChannels();

    _initialized = true;
  }

  /// Aksiyon butonu / bildirim tıklamasını işler
  static Future<void> handleAction(
    NotificationResponse response, {
    required bool allowNavigation,
  }) async {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) {
      if (allowNavigation) AppNavigator.openForPayload(response.payload);
      return;
    }

    String? relatedType;
    int? relatedId;
    String? responseType;

    if (actionId.startsWith('med_taken_') || actionId.startsWith('med_not_')) {
      relatedType = 'medication_plan';
      relatedId = int.tryParse(actionId.split('_').last);
      responseType = actionId.startsWith('med_taken_') ? 'taken' : 'not_taken';
    } else if (actionId.startsWith('habit_done_') || actionId.startsWith('habit_not_')) {
      relatedType = 'habit';
      relatedId = int.tryParse(actionId.split('_').last);
      responseType = actionId.startsWith('habit_done_') ? 'done' : 'not_done';
    }

    if (relatedId == null || responseType == null || relatedType == null) return;

    final ok = await ApiClient().submitResponse(
      relatedType: relatedType,
      relatedId: relatedId,
      response: responseType,
    );
    if (ok && allowNavigation && response.id != null) {
      await _notifications.cancel(response.id!);
    }
  }

  /// Uygulama bildirimden açıldıysa payload'ı verir
  static Future<String?> consumeLaunchPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  /// Bildirim kanalları oluştur
  static Future<void> _createNotificationChannels() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'medications',
            'İlaç Hatırlatmaları',
            description: 'İlaç alma hatırlatmaları',
            importance: Importance.max,
          ),
        );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'habits',
            'Rutin Hatırlatmaları',
            description: 'Günlük rutin hatırlatmaları',
            importance: Importance.high,
          ),
        );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'steps',
            'Adım Hatırlatmaları',
            description: 'Günlük adım hedefi hatırlatmaları',
            importance: Importance.defaultImportance,
          ),
        );
  }

  /// İzin iste (Android 13+)
  static Future<bool> requestPermission() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  /// İzin durumuna göre exact/inexact zamanlama modu seçer
  static Future<AndroidScheduleMode> _scheduleMode() async {
    final canExact = await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// İlaç hatırlatması zamanla (her gün tekrarlanır)
  static Future<void> scheduleMedicationReminder({
    required Medication medication,
  }) async {
    final timeParts = medication.reminderTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    await _notifications.zonedSchedule(
      medication.id,
      '💊 İlaç Hatırlatması',
      '${medication.name} alma zamanı geldi!',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medications',
          'İlaç Hatırlatmaları',
          channelDescription: 'İlaç alma hatırlatmaları',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'med_taken_${medication.id}',
              'İçtim ✅',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'med_not_${medication.id}',
              'İçmedim',
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'medication_${medication.id}',
    );
  }

  /// Rutin hatırlatması zamanla (seçili günlerde)
  static Future<void> scheduleHabitReminder({
    required Habit habit,
  }) async {
    final timeParts = habit.reminderTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Her gün için ayrı bildirim zamanla
    for (final day in habit.days) {
      await _notifications.zonedSchedule(
        habit.id * 10 + day, // Benzersiz ID
        '✅ Rutin Hatırlatması',
        '${habit.name} zamanı geldi!',
        _nextInstanceOfDay(day, hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'habits',
            'Rutin Hatırlatmaları',
            channelDescription: 'Günlük rutin hatırlatmaları',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                'habit_done_${habit.id}',
                'Yapıldı ✅',
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'habit_not_${habit.id}',
                'Yapmadım',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit_${habit.id}',
      );
    }
  }

  /// Adım hatırlatması (her gün 21:00)
  static Future<void> scheduleStepReminder() async {
    await _notifications.zonedSchedule(
      9999,
      '🚶 Adım Hatırlatması',
      'Bugünkü adım hedefine ulaştın mı?',
      _nextInstanceOfTime(21, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'steps',
          'Adım Hatırlatmaları',
          channelDescription: 'Günlük adım hedefi hatırlatmaları',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'steps_reminder',
    );
  }

  /// İlaç bildirimini iptal et
  static Future<void> cancelMedicationReminder(int medicationId) async {
    await _notifications.cancel(medicationId);
  }

  /// Rutin bildirimlerini iptal et
  static Future<void> cancelHabitReminders(int habitId, List<int> days) async {
    for (final day in days) {
      await _notifications.cancel(habitId * 10 + day);
    }
  }

  /// Tüm bildirimleri iptal et
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// İlaç hatırlatmalarını toplu aç/kapat
  static Future<void> setMedicationReminders(
    bool enabled,
    List<Medication> medications,
  ) async {
    for (final medication in medications) {
      if (enabled) {
        await scheduleMedicationReminder(medication: medication);
      } else {
        await cancelMedicationReminder(medication.id);
      }
    }
  }

  /// Rutin hatırlatmalarını toplu aç/kapat
  static Future<void> setHabitReminders(bool enabled, List<Habit> habits) async {
    for (final habit in habits) {
      if (enabled) {
        await scheduleHabitReminder(habit: habit);
      } else {
        await cancelHabitReminders(habit.id, habit.days);
      }
    }
  }

  /// Adım hatırlatmasını aç/kapat
  static Future<void> setStepReminder(bool enabled) async {
    if (enabled) {
      await scheduleStepReminder();
    } else {
      await _notifications.cancel(9999);
    }
  }

  /// Bir sonraki belirli saati hesapla
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Bir sonraki belirli gün ve saati hesapla
  static tz.TZDateTime _nextInstanceOfDay(int dayOfWeek, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Pazartesi = 1, Pazar = 7
    // DateTime.weekday: Pazartesi = 1, Pazar = 7
    while (scheduled.weekday != dayOfWeek || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
