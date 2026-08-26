// lib/screens/sport_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/sport_plan.dart';
import '../models/supplement_plan.dart';
import '../services/notification_service.dart';
import '../widgets/monthly_calendar_card.dart';

class SportScreen extends StatefulWidget {
  const SportScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends State<SportScreen> {
  final ApiClient _api = ApiClient();
  List<SportPlan> _plans = [];
  List<SupplementPlan> _supplements = [];
  bool _loading = true;
  String _gender = 'male';
  double? _completionRate;
  Set<int> _scheduledDays = {};
  Set<int> _completedDays = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
    AppTheme.loadGender().then((g) {
      if (mounted) setState(() => _gender = g);
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadPlans(),
      _loadMonthDays(),
      _loadMonthlyRate(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMonthDays() async {
    final now = DateTime.now();
    final sportData = await _api.getMonthDays(now.year, now.month, 'sport_bot');
    final suppData = await _api.getMonthDays(now.year, now.month, 'supplement_bot');

    final scheduled = <int>{};
    final completed = <int>{};

    if (sportData != null) {
      scheduled.addAll(_parseDays(sportData['scheduled_days'], now));
      completed.addAll(_parseDays(sportData['completed_days'], now));
    }
    if (suppData != null) {
      scheduled.addAll(_parseDays(suppData['scheduled_days'], now));
      completed.addAll(_parseDays(suppData['completed_days'], now));
    }

    if (!mounted) return;
    setState(() {
      _scheduledDays = scheduled;
      _completedDays = completed;
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
    double totalRate = 0;
    int count = 0;
    for (final stat in botStats.cast<Map<String, dynamic>>()) {
      if (stat['bot_key'] == 'sport_bot' || stat['bot_key'] == 'supplement_bot') {
        final rate = (stat['completion_rate'] as num?)?.toDouble();
        if (rate != null) {
          totalRate += rate;
          count++;
        }
      }
    }
    if (count > 0 && mounted) {
      setState(() => _completionRate = totalRate / count);
    }
  }

  Set<int> get _markedWeekdays {
    final days = <int>{};
    for (final plan in _plans) {
      for (final part in plan.daysOfWeek.split(',')) {
        final day = int.tryParse(part.trim());
        if (day != null && day >= 1 && day <= 7) {
          days.add(day);
        }
      }
    }
    for (final supp in _supplements) {
      for (final part in supp.daysOfWeek.split(',')) {
        final day = int.tryParse(part.trim());
        if (day != null && day >= 1 && day <= 7) {
          days.add(day);
        }
      }
    }
    return days;
  }

  Future<void> _loadPlans() async {
    final sportData = await _api.getSportPlans();
    final suppData = await _api.getSupplementPlans();

    final plans = sportData.map((json) => SportPlan.fromJson(json)).toList();
    final supps = suppData.map((json) => SupplementPlan.fromJson(json)).toList();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('sport_reminders') ?? true) {
      await NotificationService.setSportReminders(true, plans);
    }
    if (prefs.getBool('supplement_reminders') ?? true) {
      await NotificationService.setSupplementReminders(true, supps);
    }

    if (mounted) {
      setState(() {
        _plans = plans;
        _supplements = supps;
      });
    }
  }

  Future<void> _showAddSportDialog() async {
    final nameController = TextEditingController();
    TimeOfDay targetTime = const TimeOfDay(hour: 18, minute: 0);
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Spor Planı Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Spor Adı',
                    hintText: 'Koşu, Yoga, Ağırlık...',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Hedef Saat'),
                  subtitle: Text(
                    '${targetTime.hour}:${targetTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: targetTime,
                    );
                    if (picked != null) {
                      setState(() => targetTime = picked);
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

                final plan = SportPlan(
                  id: 0,
                  sportType: nameController.text,
                  targetHour: targetTime.hour,
                  targetMinute: targetTime.minute,
                  daysOfWeek: selectedDays.join(','),
                );

                final created = await _api.createSportPlan(plan);
                if (created != null) {
                  final prefs = await SharedPreferences.getInstance();
                  if (prefs.getBool('sport_reminders') ?? true) {
                    await NotificationService.scheduleSportReminder(plan: created);
                  }
                  if (context.mounted) Navigator.pop(context);
                  await _loadAllData();
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSupplementDialog() async {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    TimeOfDay targetTime = const TimeOfDay(hour: 9, minute: 0);
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Supplement / Takviye Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplement Adı',
                    hintText: 'Protein, Kreatin, Omega-3...',
                  ),
                ),
                TextField(
                  controller: doseController,
                  decoration: const InputDecoration(
                    labelText: 'Doz (Opsiyonel)',
                    hintText: '1 ölçek, 1000mg...',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Hatırlatma Saati'),
                  subtitle: Text(
                    '${targetTime.hour}:${targetTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: targetTime,
                    );
                    if (picked != null) {
                      setState(() => targetTime = picked);
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

                final body = {
                  'name': nameController.text,
                  'dose': doseController.text.isNotEmpty ? doseController.text : null,
                  'target_hour': targetTime.hour,
                  'target_minute': targetTime.minute,
                  'days_of_week': selectedDays.join(','),
                };

                final created = await _api.createSupplementPlan(body);
                if (created != null) {
                  final suppObj = SupplementPlan.fromJson(created);
                  final prefs = await SharedPreferences.getInstance();
                  if (prefs.getBool('supplement_reminders') ?? true) {
                    await NotificationService.scheduleSupplementReminder(supp: suppObj);
                  }
                  if (context.mounted) Navigator.pop(context);
                  await _loadAllData();
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

  Future<void> _showDeleteSportDialog(SportPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spor Planı Sil'),
        content: Text('${plan.sportType} silinecek. Emin misiniz?'),
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
      await NotificationService.cancelSportReminders(plan.id, plan.daysOfWeek);
      await _api.deleteSportPlan(plan.id);
      await _loadAllData();
    }
  }

  Future<void> _showDeleteSupplementDialog(SupplementPlan supp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supplement Sil'),
        content: Text('${supp.name} silinecek. Emin misiniz?'),
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
      await NotificationService.cancelSupplementReminders(supp.id, supp.daysOfWeek);
      await _api.deleteSupplementPlan(supp.id);
      await _loadAllData();
    }
  }

  void _showAddSelectionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.fitness_center, color: AppTheme.of(_gender)),
              title: const Text('Spor Planı Ekle'),
              onTap: () {
                Navigator.pop(context);
                _showAddSportDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.science, color: AppTheme.of(_gender)),
              title: const Text('Supplement / Takviye Ekle'),
              onTap: () {
                Navigator.pop(context);
                _showAddSupplementDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getSportAsset() {
    final prefix = _gender == 'female' ? 'sport_female_phase' : 'sport_phase';
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

  Widget _buildSportCharacterWidget() {
    final asset = _getSportAsset();
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.fitness_center,
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
              title: const Text('Spor & Supplement'),
              backgroundColor: AppTheme.of(_gender),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSelectionMenu,
        backgroundColor: AppTheme.of(_gender),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MonthlyCalendarCard(
                    title: 'Spor & Supplement Takvimi',
                    icon: Icons.fitness_center,
                    accentColor: AppTheme.of(_gender),
                    markedWeekdays: _markedWeekdays,
                    scheduledDays: _scheduledDays,
                    completedDays: _completedDays,
                    rightChild: _buildSportCharacterWidget(),
                    headerTrailing: _completionRate != null
                        ? 'Bu ay %${_completionRate!.round()}'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Spor Bölümü Başlığı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🏋️ Spor Planları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _showAddSportDialog,
                        tooltip: 'Spor Ekle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_plans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz spor planı eklenmedi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    for (final plan in _plans)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.fitness_center,
                            color: Colors.deepPurple,
                            size: 36,
                          ),
                          title: Text(
                            plan.sportType,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('⏰ ${plan.timeText}'),
                              Text('📅 ${plan.daysText}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteSportDialog(plan),
                          ),
                        ),
                      ),

                  const SizedBox(height: 20),

                  // Supplement Bölümü Başlığı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🧪 Supplement / Takviye',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _showAddSupplementDialog,
                        tooltip: 'Supplement Ekle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_supplements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz takviye eklenmedi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    for (final supp in _supplements)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.science,
                            color: Colors.orange,
                            size: 36,
                          ),
                          title: Text(
                            supp.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (supp.dose != null) Text('💊 ${supp.dose}'),
                              Text('⏰ ${supp.timeText}'),
                              Text('📅 ${supp.daysText}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteSupplementDialog(supp),
                          ),
                        ),
                      ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
