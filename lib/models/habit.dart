// lib/models/habit.dart
class Habit {
  final int id;
  final String name;
  final String reminderTime;
  final List<int> days; // 1=Pazartesi, 7=Pazar
  final bool enabled;

  Habit({
    required this.id,
    required this.name,
    required this.reminderTime,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      reminderTime: json['reminder_time'] ?? '08:00',
      days: List<int>.from(json['days'] ?? [1, 2, 3, 4, 5, 6, 7]),
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'reminder_time': reminderTime,
      'days': days,
      'enabled': enabled,
    };
  }

  /// Gün isimlerini Türkçe'ye çevir
  String get daysText {
    if (days.length == 7) return 'Her gün';

    final dayNames = {
      1: 'Pzt', 2: 'Sal', 3: 'Çar', 4: 'Per',
      5: 'Cum', 6: 'Cmt', 7: 'Paz',
    };

    return days.map((d) => dayNames[d] ?? '').join(', ');
  }
}
