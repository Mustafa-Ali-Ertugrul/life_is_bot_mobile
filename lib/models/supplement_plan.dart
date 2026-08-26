// lib/models/supplement_plan.dart
class SupplementPlan {
  final int id;
  final String name;
  final String? dose;
  final int targetHour;
  final int targetMinute;
  final String daysOfWeek;
  final bool enabled;

  SupplementPlan({
    required this.id,
    required this.name,
    this.dose,
    required this.targetHour,
    required this.targetMinute,
    required this.daysOfWeek,
    this.enabled = true,
  });

  factory SupplementPlan.fromJson(Map<String, dynamic> json) {
    return SupplementPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      dose: json['dose'],
      targetHour: json['target_hour'] ?? 8,
      targetMinute: json['target_minute'] ?? 0,
      daysOfWeek: json['days_of_week'] ?? '1,2,3,4,5,6,7',
      enabled: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dose': dose,
      'target_hour': targetHour,
      'target_minute': targetMinute,
      'days_of_week': daysOfWeek,
    };
  }

  String get timeText =>
      '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}';

  String get daysText {
    if (daysOfWeek == '1,2,3,4,5,6,7') return 'Her Gün';
    final parts = daysOfWeek.split(',').map((e) => e.trim());
    const names = {
      '1': 'Pzt',
      '2': 'Sal',
      '3': 'Çar',
      '4': 'Per',
      '5': 'Cum',
      '6': 'Cmt',
      '7': 'Paz',
    };
    return parts.map((e) => names[e] ?? e).join(', ');
  }
}
