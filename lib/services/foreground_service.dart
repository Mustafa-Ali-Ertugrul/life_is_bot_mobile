// lib/services/foreground_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

/// Foreground service that keeps the process alive on MIUI/Xiaomi devices.
///
/// MIUI aggressively hibernates background apps, preventing
/// RTC_WAKEUP alarms from firing. This service runs in foreground mode
/// with a persistent low-importance notification, which prevents the
/// OS from killing the process.
///
/// The service itself does not re-schedule alarms; scheduled alarms
/// are managed by flutter_local_notifications (with its boot receiver
/// restoring them after reboot). This service only keeps the process alive.
@pragma('vm:entry-point')
class ForegroundService {
  static const int _notificationId = 1001;
  static const String _channelId = 'lifeisbot_foreground';

  static bool _initialized = false;

  /// Initialize and start the foreground service.
  /// Must be called from main isolate before runApp().
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final service = FlutterBackgroundService();

    // Must match the channel in our app's notification_service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'Life Is Bot',
      description: 'Hatırlatma servisi',
      importance: Importance.low,
    );

    final flutterLocalNotificationsPlugin =
        NotificationService.localNotifications;

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Life Is Bot',
        initialNotificationContent: 'Hatırlatmalar aktif',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );

    service.startService();
  }

  /// Entry point for the foreground service (runs in a separate isolate).
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    // Periodically check that the process is alive (every 60s)
    // This keeps the MIUI watchdog satisfied.
    Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification with current time to show activity
          service.setForegroundNotificationInfo(
            title: 'Life Is Bot',
            content: 'Hatırlatmalar aktif — ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          );
        }
      }
    });
  }

  /// Stop the foreground service.
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}