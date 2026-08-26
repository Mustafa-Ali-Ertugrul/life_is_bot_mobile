// lib/models/sport_plan.dart
class SportPlan {
  final int id;
  final String sportType;
  final int targetHour;
  final int targetMinute;
  final String daysOfWeek;
  final bool isActive;

  SportPlan({
    required this.id,
    required this.sportType,
    required this.targetHour,
    required this.targetMinute,
    this.daysOfWeek = '1,2,3,4,5,6,7',
    this.isActive = true,
  });

  factory SportPlan.fromJson(Map<String, dynamic> json) {
    return SportPlan(
      id: json['id'] ?? 0,
      sportType: json['sport_type'] ?? '',
      targetHour: json['target_hour'] ?? 0,
      targetMinute: json['target_minute'] ?? 0,
      daysOfWeek: json['days_of_week'] ?? '1,2,3,4,5,6,7',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sport_type': sportType,
      'target_hour': targetHour,
      'target_minute': targetMinute,
      'days_of_week': daysOfWeek,
      'is_active': isActive,
    };
  }

  String get timeText =>
      '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}';

  String get daysText {
    const names = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final days = daysOfWeek
        .split(',')
        .map((d) => int.tryParse(d.trim()))
        .whereType<int>()
        .toList();
    if (days.isEmpty || days.length == 7) return 'Her gün';
    return days
        .where((d) => d >= 1 && d <= 7)
        .map((d) => names[d])
        .join(', ');
  }
}
