// lib/models/medication.dart
class Medication {
  /// İlaç hatırlatmaları her gün tekrar eder (bildirim DateTimeComponents.time
  /// ile günlük planlanır); backend bu yüzden tüm günleri bekler.
  static const String everyDayDaysOfWeek = '1,2,3,4,5,6,7';

  final int id;
  final String name;
  final String? dosage;
  final String reminderTime;
  final bool enabled;

  Medication({
    required this.id,
    required this.name,
    this.dosage,
    required this.reminderTime,
    this.enabled = true,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    final hour = json['target_hour'] as int?;
    final minute = json['target_minute'] as int?;
    final reminderTime = (hour != null && minute != null)
        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        : (json['reminder_time'] ?? '08:00');
    return Medication(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      dosage: json['dose'] ?? json['dosage'],
      reminderTime: reminderTime,
      enabled: json['is_active'] ?? json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final parts = reminderTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return {
      'name': name,
      'dose': dosage,
      'target_hour': hour,
      'target_minute': minute,
      'days_of_week': everyDayDaysOfWeek,
    };
  }
}
