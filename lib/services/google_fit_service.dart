import 'package:google_fit/google_fit.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/database.dart';

class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final GoogleFit _googleFit = GoogleFit();

  /// Google Fit permission iste
  Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();

    if (status.isGranted) {
      await _googleFit.requestPermissions([
        FitnessPermission(
          dataType: DataType.steps,
          access: FitnessAccess.read,
        ),
      ]);
      return true;
    }

    return false;
  }

  /// Google Fit yüklü mü kontrol et
  Future<bool> isAvailable() async {
    return await _googleFit.isAvailable();
  }

  /// Bugünkü adımları al
  Future<int> getTodaySteps() async {
    if (!await isAvailable()) {
      return 0;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final result = await _googleFit.getData(
        dataType: DataType.steps,
        startTime: startOfDay,
        endTime: now,
      );

      return result.fold(0, (sum, data) => sum + data.value.toInt());
    } catch (e) {
      print('Error fetching steps: $e');
      return 0;
    }
  }

  /// Son 7 günün adımlarını al
  Future<Map<DateTime, int>> getWeeklySteps() async {
    if (!await isAvailable()) {
      return {};
    }

    final now = DateTime.now();
    final stepsMap = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      try {
        final result = await _googleFit.getData(
          dataType: DataType.steps,
          startTime: startOfDay,
          endTime: endOfDay,
        );

        final steps = result.fold(0, (sum, data) => sum + data.value.toInt());
        stepsMap[startOfDay] = steps;
      } catch (e) {
        print('Error fetching steps for $date: $e');
        stepsMap[startOfDay] = 0;
      }
    }

    return stepsMap;
  }

  /// Adımları sync et (Google Fit → Local DB)
  Future<void> syncSteps() async {
    final steps = await getTodaySteps();
    final today = DateTime.now();

    final db = await DatabaseService.instance;
    await db.saveSteps(
      steps: steps,
      date: today,
      source: 'google_fit',
    );

    print('Synced $steps steps for ${today.toString().split(' ')[0]}');
  }
}
