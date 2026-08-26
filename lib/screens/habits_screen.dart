// lib/screens/habits_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../widgets/monthly_calendar_card.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final ApiClient _api = ApiClient();
  List<Habit> _habits = [];
  bool _loading = true;
  String _gender = 'male';
  double? _completionRate;
  Set<int> _scheduledDays = {};
  Set<int> _completedDays = {};

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _loadMonthlyRate();
    _loadMonthDays();
    AppTheme.loadGender().then((g) {
      if (mounted) setState(() => _gender = g);
    });
  }

  Future<void> _loadMonthDays() async {
    final now = DateTime.now();
    final data = await _api.getMonthDays(now.year, now.month, 'habit_bot');
    if (data == null || !mounted) return;
    setState(() {
      _scheduledDays = _parseDays(data['scheduled_days'], now);
      _completedDays = _parseDays(data['completed_days'], now);
    });
  }

  Set<int> _parseDays(Object? value, DateTime now) {
    final days = <int>{};
    if (value is List) {
      for (final item in value) {
        final parsed = DateTime.tryParse('$item');
        if (parsed != null &&
            parsed.year == now.year &&
            parsed.month == now.month) {
          days.add(parsed.day);
        }
      }
    }
    return days;
  }

  Future<void> _loadMonthlyRate() async {
    final report = await _api.getMonthlyReport();
    if (report == null) return;
    final botStats = report['bot_stats'];
    if (botStats is! List) return;
    for (final stat in botStats.cast<Map<String, dynamic>>()) {
      if (stat['bot_key'] == 'habit_bot') {
        final rate = (stat['completion_rate'] as num?)?.toDouble();
        if (rate != null && mounted) {
          setState(() => _completionRate = rate);
        }
        return;
      }
    }
  }

  Set<int> get _markedWeekdays {
    final days = <int>{};
    for (final habit in _habits) {
      days.addAll(habit.days);
    }
    return days;
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);

    final data = await _api.getHabits();
    final habits = data.map((json) => Habit.fromJson(json)).toList();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('habit_reminders') ?? true) {
      await NotificationService.setHabitReminders(true, habits);
    }

    setState(() {
      _habits = habits;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rutin Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Rutin Adı',
                    hintText: 'Meditasyon',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Hatırlatma Saati'),
                  subtitle: Text(
                    '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminderTime,
                    );
                    if (picked != null) {
                      setState(() => reminderTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Günler:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDayChip(1, 'Pzt', selectedDays, setState),
                    _buildDayChip(2, 'Sal', selectedDays, setState),
                    _buildDayChip(3, 'Çar', selectedDays, setState),
                    _buildDayChip(4, 'Per', selectedDays, setState),
                    _buildDayChip(5, 'Cum', selectedDays, setState),
                    _buildDayChip(6, 'Cmt', selectedDays, setState),
                    _buildDayChip(7, 'Paz', selectedDays, setState),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final habit = Habit(
                  id: 0,
                  name: nameController.text,
                  reminderTime: '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
                  days: List<int>.from(selectedDays),
                );

                final created = await _api.createHabit(habit);
                if (created != null) {
                  final prefs = await SharedPreferences.getInstance();
                  if (prefs.getBool('habit_reminders') ?? true) {
                    await NotificationService.scheduleHabitReminder(habit: created);
                  }
                  if (context.mounted) Navigator.pop(context);
                  await _loadHabits();
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(
    int day,
    String label,
    List<int> selectedDays,
    StateSetter setState,
  ) {
    final isSelected = selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedDays.add(day);
          } else {
            selectedDays.remove(day);
          }
        });
      },
      selectedColor: AppTheme.of(_gender),
      checkmarkColor: Colors.white,
    );
  }

  Future<void> _showDeleteDialog(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rutin Sil'),
        content: Text('${habit.name} silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService.cancelHabitReminders(habit.id, habit.days);
      await _api.deleteHabit(habit.id);
      await _loadHabits();
    }
  }

  String _getRoutineAsset() {
    final prefix = _gender == 'female' ? 'routine_female_phase' : 'routine_phase';
    final completedCount = _completedDays.length;
    if (completedCount >= 15 || (_completionRate != null && _completionRate! >= 75)) {
      return 'assets/images/${prefix}_4.gif';
    } else if (completedCount >= 10 || (_completionRate != null && _completionRate! >= 50)) {
      return 'assets/images/${prefix}_3.gif';
    } else if (completedCount >= 5 || (_completionRate != null && _completionRate! >= 25)) {
      return 'assets/images/${prefix}_2.gif';
    } else {
      return 'assets/images/${prefix}_1.gif';
    }
  }

  Widget _buildRoutineCharacterWidget() {
    final asset = _getRoutineAsset();
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.check_circle,
          size: 64,
          color: AppTheme.of(_gender),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Rutin Takibi'),
              backgroundColor: AppTheme.of(_gender),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.of(_gender),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadHabits(),
                  _loadMonthDays(),
                  _loadMonthlyRate(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MonthlyCalendarCard(
                    title: 'Rutin Takvimi',
                    icon: Icons.check_circle,
                    accentColor: AppTheme.of(_gender),
                    markedWeekdays: _markedWeekdays,
                    scheduledDays: _scheduledDays,
                    completedDays: _completedDays,
                    rightChild: _buildRoutineCharacterWidget(),
                    headerTrailing: _completionRate != null
                        ? 'Bu ay %${_completionRate!.round()}'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_habits.isEmpty)
                    _buildEmptyState()
                  else
                    for (final habit in _habits)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 40,
                          ),
                          title: Text(
                            habit.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⏰ ${habit.reminderTime}'),
                              Text('📅 ${habit.daysText}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(habit),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Henüz rutin eklenmedi',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showAddDialog,
            child: const Text('İlk rutinini ekle'),
          ),
        ],
      ),
    );
  }
}
