import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final ApiClient _api = ApiClient();
  List<Medication> _medications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() => _loading = true);
    final data = await _api.getMedications();
    final medications = data.map((json) => Medication.fromJson(json)).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç Takibi'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? const Center(child: Text('Henüz ilaç eklenmedi'))
              : RefreshIndicator(
                  onRefresh: _loadMedications,
                  child: ListView.builder(
                    itemCount: _medications.length,
                    itemBuilder: (context, index) {
                      final medication = _medications[index];
                      return ListTile(
                        leading: const Icon(Icons.medication, color: Colors.red),
                        title: Text(medication.name),
                        subtitle: Text('${medication.dosage ?? ""} - ⏰ ${medication.reminderTime}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteDialog(medication),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
