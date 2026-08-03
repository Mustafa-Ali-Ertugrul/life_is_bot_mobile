import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/database.dart';

class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final Health _health = Health();
  bool _initialized = false;

  /// Health service'ı başlat
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _health.configure();
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('Health init error: $e');
      return false;
    }
  }

  /// Permission iste
  Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return false;

    final types = [HealthDataType.STEPS];
    final requested = await _health.requestAuthorization(types);
    return requested;
  }

  /// Google Fit/Health var mı kontrol et
  Future<bool> isAvailable() async {
    return await initialize();
  }

  /// Bugünkü adımları al
  Future<int> getTodaySteps() async {
    if (!await isAvailable()) return 0;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint('Error fetching steps: $e');
      return 0;
    }
  }

  /// Son 7 günün adımlarını al
  Future<Map<DateTime, int>> getWeeklySteps() async {
    if (!await isAvailable()) return {};

    final now = DateTime.now();
    final stepsMap = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      try {
        final steps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
        stepsMap[startOfDay] = steps ?? 0;
      } catch (e) {
        debugPrint('Error fetching steps for $date: $e');
        stepsMap[startOfDay] = 0;
      }
    }

    return stepsMap;
  }

  /// Adımları sync et
  Future<void> syncSteps() async {
    final steps = await getTodaySteps();
    final today = DateTime.now();

    final db = DatabaseService();
    await db.saveSteps(
      steps: steps,
      date: today,
      source: 'google_fit',
    );

    debugPrint('Synced $steps steps for ${today.toString().split(' ')[0]}');
  }
}
