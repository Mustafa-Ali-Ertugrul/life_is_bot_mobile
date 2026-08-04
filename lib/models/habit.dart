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
    final hour = json['target_hour'] as int?;
    final minute = json['target_minute'] as int?;
    final reminderTime = (hour != null && minute != null)
        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        : (json['reminder_time'] ?? '08:00');
    final daysOfWeek = json['days_of_week'];
    final days = daysOfWeek is String && daysOfWeek.isNotEmpty
        ? daysOfWeek.split(',').map((d) => int.tryParse(d.trim()) ?? 0).where((d) => d >= 1 && d <= 7).toList()
        : List<int>.from(json['days'] ?? [1, 2, 3, 4, 5, 6, 7]);
    return Habit(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      reminderTime: reminderTime,
      days: days.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : days,
      enabled: json['is_active'] ?? json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final parts = reminderTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return {
      'name': name,
      'target_hour': hour,
      'target_minute': minute,
      'days_of_week': days.join(','),
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
