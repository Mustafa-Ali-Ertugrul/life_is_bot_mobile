import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../widgets/monthly_calendar_card.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, this.embedded = false, this.focusId});

  final bool embedded;

  /// Bildirim payload'ından gelen odaklanılacak öğe id'si
  final int? focusId;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final ApiClient _api = ApiClient();
  List<Medication> _medications = [];
  bool _loading = true;
  String _gender = 'male';
  double? _completionRate;
  Set<int> _scheduledDays = {};
  Set<int> _completedDays = {};
  bool _focusVisible = true;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _loadMonthlyRate();
    _loadMonthDays();
    AppTheme.loadGender().then((g) {
      if (mounted) setState(() => _gender = g);
    });
    if (widget.focusId != null) {
      _focusTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _focusVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMonthDays() async {
    final now = DateTime.now();
    final data = await _api.getMonthDays(now.year, now.month, 'medication_bot');
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
      if (stat['bot_key'] == 'medication_bot') {
        final rate = (stat['completion_rate'] as num?)?.toDouble();
        if (rate != null && mounted) {
          setState(() => _completionRate = rate);
        }
        return;
      }
    }
  }

  Future<void> _loadMedications() async {
    setState(() => _loading = true);
    final data = await _api.getMedications();
    final medications = data.map((json) => Medication.fromJson(json)).toList();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('medication_reminders') ?? true) {
      await NotificationService.setMedicationReminders(true, medications);
    }
    setState(() {
      _medications = medications;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('İlaç Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'İlaç Adı'),
                ),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(labelText: 'Dozaj (Opsiyonel)'),
                ),
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

                final medication = Medication(
                  id: 0,
                  name: nameController.text,
                  dosage: dosageController.text.isNotEmpty ? dosageController.text : null,
                  reminderTime: '${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, '0')}',
                );

                final created = await _api.createMedication(medication);
                if (created != null) {
                  final prefs = await SharedPreferences.getInstance();
                  if (prefs.getBool('medication_reminders') ?? true) {
                    await NotificationService.scheduleMedicationReminder(medication: created);
                  }
                  if (context.mounted) Navigator.pop(context);
                  await _loadMedications();
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlaç Sil'),
        content: Text('${medication.name} silinecek. Emin misiniz?'),
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
      await NotificationService.cancelMedicationReminder(medication.id);
      await _api.deleteMedication(medication.id);
      await _loadMedications();
    }
  }

  Set<int> get _markedWeekdays {
    if (_medications.isEmpty) return {};
    return {1, 2, 3, 4, 5, 6, 7};
  }

  bool _isFocused(int id) => _focusVisible && widget.focusId == id;

  String _getMedicationAsset() {
    final completedCount = _completedDays.length;
    if (completedCount >= 15 ||
        (_completionRate != null && _completionRate! >= 75)) {
      return 'assets/images/medication_phase_4.gif';
    } else if (completedCount >= 10 ||
        (_completionRate != null && _completionRate! >= 50)) {
      return 'assets/images/medication_phase_3.gif';
    } else if (completedCount >= 5 ||
        (_completionRate != null && _completionRate! >= 25)) {
      return 'assets/images/medication_phase_2.gif';
    } else {
      return 'assets/images/medication_phase_1.gif';
    }
  }

  Widget _buildMedicationCharacterWidget() {
    final asset = _getMedicationAsset();
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.medication,
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
              title: const Text('İlaç Takibi'),
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
                  _loadMedications(),
                  _loadMonthDays(),
                  _loadMonthlyRate(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MonthlyCalendarCard(
                    title: 'İlaç Takvimi',
                    icon: Icons.medication,
                    accentColor: AppTheme.of(_gender),
                    markedWeekdays: _markedWeekdays,
                    scheduledDays: _scheduledDays,
                    completedDays: _completedDays,
                    rightChild: _buildMedicationCharacterWidget(),
                    headerTrailing: _completionRate != null
                        ? 'Bu ay %${_completionRate!.round()}'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_medications.isEmpty)
                    _api.groupFailed('medications')
                        ? _buildConnectionError()
                        : _buildEmptyState()
                  else
                    for (final medication in _medications)
                      Card(
                        color: _isFocused(medication.id)
                            ? AppTheme.of(_gender).withValues(alpha: 0.15)
                            : null,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.medication, color: Colors.red),
                          title: Text(medication.name),
                          subtitle: Text(
                              '${medication.dosage ?? ""} - ⏰ ${medication.reminderTime}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(medication),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Sunucuya bağlanılamadı',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Liste yüklenemedi. Bağlantını kontrol edip yeniden dene.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadMedications,
            icon: const Icon(Icons.refresh),
            label: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medication, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Henüz ilaç eklenmedi',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('İlk ilacını ekle'),
          ),
        ],
      ),
    );
  }
}
