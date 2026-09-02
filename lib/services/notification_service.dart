// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_navigator.dart';
import '../core/notification_ids.dart';
import '../models/medication.dart';
import '../models/habit.dart';
import '../models/sport_plan.dart';
import '../models/supplement_plan.dart';

/// Uygulama kapalıyken bildirim aksiyonlarını işler (background isolate)
@pragma('vm:entry-point')
void backgroundNotificationHandler(NotificationResponse response) async {
  await NotificationService.handleAction(response, allowNavigation: false);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get localNotifications =>
      _notifications;

  static bool _initialized = false;

  // Bildirim ID'leri tek doğruluk kaynağından gelir: NotificationIds.
  // Formüller bu dosyada KOPYALANMAZ — schedule/cancel hep orayı çağırır.

  /// Bildirim servisini başlat
  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    } catch (e) {
      debugPrint('⚠️ Timezone set error: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) =>
          handleAction(response, allowNavigation: true),
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
    );

    await _createNotificationChannels();
    await _purgeLegacyNotificationIds();
    _initialized = true;
  }

  /// ID şeması güncellendiğinde (v2→v3: med artık 1M bandında, step 500M'de)
  /// eski şemayla zamanlanmış bildirimleri tek seferlik temizler. Yoksa eski
  /// ID'ler yetim kalır ve iptal edilemezler.
  static Future<void> _purgeLegacyNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_id_scheme_v3') ?? false) return;
    await _notifications.cancelAll();
    await prefs.setBool('notif_id_scheme_v3', true);
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
    } else if (actionId.startsWith('sport_done_') || actionId.startsWith('sport_not_')) {
      relatedType = 'sport_plan';
      relatedId = int.tryParse(actionId.split('_').last);
      responseType = actionId.startsWith('sport_done_') ? 'done' : 'not_done';
    } else if (actionId.startsWith('supp_done_') || actionId.startsWith('supp_not_')) {
      relatedType = 'supplement_plan';
      relatedId = int.tryParse(actionId.split('_').last);
      responseType = actionId.startsWith('supp_done_') ? 'done' : 'not_done';
    }

    if (relatedId == null || responseType == null || relatedType == null) return;

    // Aksiyon butonları cancelNotification: true ile bildirimi zaten kapatır;
    // burada tekrar cancel gerekmez. Başarısız kayıt log ile görünür olsun.
    final ok = await ApiClient().submitResponse(
      relatedType: relatedType,
      relatedId: relatedId,
      response: responseType,
    );
    if (!ok) {
      debugPrint(
          '⚠️ Bildirim aksiyonu kaydedilemedi: $relatedType#$relatedId → $responseType');
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

  /// Bildirim kanalları oluştur (Importance.max & Alarm sesi kullanımı ile 10 sn tam çalma)
  static Future<void> _createNotificationChannels() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    const customSound = RawResourceAndroidNotificationSound('notification_sound');

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'medications_v4',
        'İlaç Hatırlatmaları',
        description: 'İlaç alma hatırlatmaları',
        importance: Importance.max,
        playSound: true,
        sound: customSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'habits_v4',
        'Rutin Hatırlatmaları',
        description: 'Günlük rutin hatırlatmaları',
        importance: Importance.max,
        playSound: true,
        sound: customSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'sport_v4',
        'Spor Hatırlatmaları',
        description: 'Spor planı hatırlatmaları',
        importance: Importance.max,
        playSound: true,
        sound: customSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'supplement_v4',
        'Takviye Hatırlatmaları',
        description: 'Supplement / Takviye alma hatırlatmaları',
        importance: Importance.max,
        playSound: true,
        sound: customSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'steps_v4',
        'Adım Hatırlatmaları',
        description: 'Günlük adım hedefi hatırlatmaları',
        importance: Importance.high,
        playSound: true,
        sound: customSound,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  /// İzin iste (Android 13+ bildirim & exact alarm izinleri)
  /// Idempotent: izin zaten verilmişse hiçbir sistem diyaloğu açmaz.
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;

    final notifGranted = await androidImpl.requestNotificationsPermission();
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (_) {}

    return notifGranted ?? false;
  }

  /// Sistem ayarlarındaki bildirim izin sayfasını aç
  static Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  /// İzin durumuna göre alarmClock / exact modu seçer (MIUI/Doze modunu aşmak için alarmClock)
  static Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      final canExact = await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          false;
      return canExact
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// İlaç hatırlatması zamanla (her gün tekrarlanır)
  static Future<void> scheduleMedicationReminder({
    required Medication medication,
  }) async {
    final timeParts = medication.reminderTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final nextTime = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      NotificationIds.medication(medication.id),
      '💊 İlaç Hatırlatması',
      '${medication.name} alma zamanı geldi!',
      nextTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medications_v4',
          'İlaç Hatırlatmaları',
          channelDescription: 'İlaç alma hatırlatmaları',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
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

    for (final day in habit.days) {
      final nextTime = _nextInstanceOfDay(day, hour, minute);
      await _notifications.zonedSchedule(
        NotificationIds.habit(habit.id, day),
        '✅ Rutin Hatırlatması',
        '${habit.name} zamanı geldi!',
        nextTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'habits_v4',
            'Rutin Hatırlatmaları',
            channelDescription: 'Günlük rutin hatırlatmaları',
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('notification_sound'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
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

  /// Spor hatırlatması zamanla (seçili günlerde)
  static Future<void> scheduleSportReminder({
    required SportPlan plan,
  }) async {
    final days = plan.daysOfWeek
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    for (final day in days) {
      final nextTime = _nextInstanceOfDay(day, plan.targetHour, plan.targetMinute);
      await _notifications.zonedSchedule(
        NotificationIds.sport(plan.id, day),
        '🏋️ Spor Hatırlatması',
        '${plan.sportType} antrenmanı zamanı geldi!',
        nextTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sport_v4',
            'Spor Hatırlatmaları',
            channelDescription: 'Spor planı hatırlatmaları',
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('notification_sound'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            actions: [
              AndroidNotificationAction(
                'sport_done_${plan.id}',
                'Yaptım ✅',
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'sport_not_${plan.id}',
                'Yapmadım',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'sport_${plan.id}',
      );
    }
  }

  /// Supplement hatırlatması zamanla (seçili günlerde)
  static Future<void> scheduleSupplementReminder({
    required SupplementPlan supp,
  }) async {
    final days = supp.daysOfWeek
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    for (final day in days) {
      final nextTime = _nextInstanceOfDay(day, supp.targetHour, supp.targetMinute);
      await _notifications.zonedSchedule(
        NotificationIds.supplement(supp.id, day),
        '🧪 Supplement Hatırlatması',
        '${supp.name} ${supp.dose != null ? "(${supp.dose})" : ""} alma zamanı!',
        nextTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'supplement_v4',
            'Takviye Hatırlatmaları',
            channelDescription: 'Supplement / Takviye alma hatırlatmaları',
            importance: Importance.max,
            priority: Priority.max,
            visibility: NotificationVisibility.public,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('notification_sound'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            actions: [
              AndroidNotificationAction(
                'supp_done_${supp.id}',
                'Aldım ✅',
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'supp_not_${supp.id}',
                'Almadım',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'supplement_${supp.id}',
      );
    }
  }

  /// Adım hatırlatması (kullanıcının seçtiği saat; varsayılan 21:00)
  static Future<void> scheduleStepReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('step_reminder_hour') ?? 21;
    final minute = prefs.getInt('step_reminder_minute') ?? 0;
    await _notifications.zonedSchedule(
      NotificationIds.step,
      '🚶 Adım Hatırlatması',
      'Bugünkü adım hedefine ulaştın mı?',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'steps_v4',
          'Adım Hatırlatmaları',
          channelDescription: 'Günlük adım hedefi hatırlatmaları',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'steps_reminder',
    );
  }

  /// Test: ilaç botu için anında bildirim gösterir (debug amaçlı).
  static Future<void> showTestBotNotifications() async {
    await _notifications.show(
      7101,
      '💊 Test: İlaç Botu',
      'İlaç hatırlatması test bildirimi',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medications_v4',
          'İlaç Hatırlatmaları',
          channelDescription: 'İlaç alma hatırlatmaları',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      ),
    );
  }

  /// İlaç bildirimini iptal et
  static Future<void> cancelMedicationReminder(int medicationId) async {
    await _notifications.cancel(NotificationIds.medication(medicationId));
  }

  /// Rutin bildirimlerini iptal et
  static Future<void> cancelHabitReminders(int habitId, List<int> days) async {
    for (final day in days) {
      await _notifications.cancel(NotificationIds.habit(habitId, day));
    }
  }

  /// Spor bildirimlerini iptal et
  static Future<void> cancelSportReminders(int planId, String daysOfWeek) async {
    final days = daysOfWeek
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    for (final day in days) {
      await _notifications.cancel(NotificationIds.sport(planId, day));
    }
  }

  /// Supplement bildirimlerini iptal et
  static Future<void> cancelSupplementReminders(int suppId, String daysOfWeek) async {
    final days = daysOfWeek
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    for (final day in days) {
      await _notifications.cancel(NotificationIds.supplement(suppId, day));
    }
  }

  /// Tüm bildirimleri iptal et
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// İlaç hatırlatmalarını toplu güncelle
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

  /// Rutin hatırlatmalarını toplu güncelle
  static Future<void> setHabitReminders(bool enabled, List<Habit> habits) async {
    for (final habit in habits) {
      if (enabled) {
        await scheduleHabitReminder(habit: habit);
      } else {
        await cancelHabitReminders(habit.id, habit.days);
      }
    }
  }

  /// Spor hatırlatmalarını toplu güncelle
  static Future<void> setSportReminders(bool enabled, List<SportPlan> plans) async {
    for (final plan in plans) {
      if (enabled) {
        await scheduleSportReminder(plan: plan);
      } else {
        await cancelSportReminders(plan.id, plan.daysOfWeek);
      }
    }
  }

  /// Supplement hatırlatmalarını toplu güncelle
  static Future<void> setSupplementReminders(
      bool enabled, List<SupplementPlan> supps) async {
    for (final supp in supps) {
      if (enabled) {
        await scheduleSupplementReminder(supp: supp);
      } else {
        await cancelSupplementReminders(supp.id, supp.daysOfWeek);
      }
    }
  }

  /// Adım hatırlatmasını aç/kapat
  static Future<void> setStepReminder(bool enabled) async {
    if (enabled) {
      await scheduleStepReminder();
    } else {
      await _notifications.cancel(NotificationIds.step);
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

    while (scheduled.weekday != dayOfWeek || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
