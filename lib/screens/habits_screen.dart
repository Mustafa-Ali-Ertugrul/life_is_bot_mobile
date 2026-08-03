// lib/screens/habits_screen.dart
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final ApiClient _api = ApiClient();
  List<Habit> _habits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);

    final data = await _api.getHabits();
    final habits = data.map((json) => Habit.fromJson(json)).toList();

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
                  await NotificationService.scheduleHabitReminder(habit: created);
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
      selectedColor: Colors.teal,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutin Takibi'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? Center(
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
                )
              : RefreshIndicator(
                  onRefresh: _loadHabits,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      return Card(
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
                      );
                    },
                  ),
                ),
    );
  }
}
