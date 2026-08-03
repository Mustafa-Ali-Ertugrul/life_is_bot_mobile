// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medication.dart';
import '../models/habit.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Bildirim servisini başlat
  static Future<void> init() async {
    if (_initialized) return;

    // Timezone başlat
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Bildirime tıklanınca çalışır
      },
    );

    // Android 13+ için bildirim kanalı oluştur
    await _createNotificationChannels();

    _initialized = true;
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medications',
          'İlaç Hatırlatmaları',
          channelDescription: 'İlaç alma hatırlatmaları',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habits',
            'Rutin Hatırlatmaları',
            channelDescription: 'Günlük rutin hatırlatmaları',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
