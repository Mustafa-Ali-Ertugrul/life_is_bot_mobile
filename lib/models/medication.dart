// lib/models/medication.dart
class Medication {
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
    return Medication(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      dosage: json['dosage'],
      reminderTime: json['reminder_time'] ?? '08:00',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'reminder_time': reminderTime,
      'enabled': enabled,
    };
  }
}
