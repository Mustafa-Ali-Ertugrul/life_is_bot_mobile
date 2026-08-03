import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/database.dart';

class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final Health _health = Health();

  // Define the types to get.
  final List<HealthDataType> types = [
    HealthDataType.STEPS,
  ];

  /// Health permissions iste
  Future<bool> requestPermission() async {
    // Activity recognition permission (Android specific)
    final status = await Permission.activityRecognition.request();

    if (status.isGranted) {
      // Health permissions
      bool requested = await _health.requestAuthorization(types);
      return requested;
    }

    return false;
  }

  /// Health yüklü mü kontrol et (Android için Google Fit/Health Connect)
  Future<bool> isAvailable() async {
    // Note: On Android, this checks for Health Connect if configured,
    // or Google Fit.
    return true; // Simplified for now as Health.isAvailable() is not direct
  }

  /// Bugünkü adımları al
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      // Get cumulative steps for today
      int? steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps ?? 0;
    } catch (e) {
      print('Error fetching steps: $e');
      return 0;
    }
  }

  /// Son 7 günün adımlarını al
  Future<Map<DateTime, int>> getWeeklySteps() async {
    final now = DateTime.now();
    final stepsMap = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      try {
        int? steps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
        stepsMap[startOfDay] = steps ?? 0;
      } catch (e) {
        print('Error fetching steps for $date: $e');
        stepsMap[startOfDay] = 0;
      }
    }

    return stepsMap;
  }

  /// Adımları sync et (Health -> Local DB)
  Future<void> syncSteps() async {
    final steps = await getTodaySteps();
    final today = DateTime.now();

    final db = await DatabaseService.instance;
    await db.saveSteps(
      steps: steps,
      date: today,
      source: 'health_api',
    );

    print('Synced $steps steps for ${today.toString().split(' ')[0]}');
  }
}
