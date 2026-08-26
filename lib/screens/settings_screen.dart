import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../main.dart';
import '../models/medication.dart';
import '../models/habit.dart';
import '../models/sport_plan.dart';
import '../models/supplement_plan.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _stepGoalController = TextEditingController();

  bool _medicationReminders = true;
  bool _habitReminders = true;
  bool _sportReminders = true;
  bool _supplementReminders = true;
  bool _stepReminders = true;
  bool _backendConnected = false;
  bool _loading = true;
  String _gender = 'male'; // 'male' -> Turkuaz (teal), 'female' -> Yeşil (green)
  String _themeMode = 'system';

  // Bot Modül Durumları
  final Map<String, bool> _botPreferences = {
    'medication_bot': true,
    'habit_bot': true,
    'sport_bot': true,
    'supplement_bot': false,
    'step_bot': true,
    'assessment_bot': false,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final goal = await _api.getStepGoal();
    _backendConnected = await _api.checkHealth();

    if (_backendConnected) {
      final preferences = await _api.getPreferences();
      for (var pref in preferences) {
        final key = pref['bot_key'] as String?;
        final enabled = pref['enabled'] as bool?;
        if (key != null && enabled != null) {
          _botPreferences[key] = enabled;
        }
      }
    }

    if (mounted) {
      setState(() {
        _gender = prefs.getString('user_gender') ?? 'male';
        _themeMode = prefs.getString('theme_mode') ?? 'system';
        _stepGoalController.text = goal.toString();
        _medicationReminders = prefs.getBool('medication_reminders') ?? true;
        _habitReminders = prefs.getBool('habit_reminders') ?? true;
        _sportReminders = prefs.getBool('sport_reminders') ?? true;
        _supplementReminders = prefs.getBool('supplement_reminders') ?? true;
        _stepReminders = prefs.getBool('step_reminders') ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _changeTheme(String? val) async {
    if (val == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', val);
    setState(() {
      _themeMode = val;
    });

    ThemeMode mode = ThemeMode.system;
    if (val == 'light') mode = ThemeMode.light;
    if (val == 'dark') mode = ThemeMode.dark;

    if (mounted) {
      MyApp.setThemeMode(context, mode);
    }
  }

  Future<void> _changeGender(String? val) async {
    if (val == null || val == _gender) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_gender', val);
    if (mounted) {
      setState(() => _gender = val);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newGoal = int.tryParse(_stepGoalController.text) ?? 10000;

    await prefs.setBool('medication_reminders', _medicationReminders);
    await prefs.setBool('habit_reminders', _habitReminders);
    await prefs.setBool('sport_reminders', _sportReminders);
    await prefs.setBool('supplement_reminders', _supplementReminders);
    await prefs.setBool('step_reminders', _stepReminders);

    if (_backendConnected) {
      await _api.updateStepGoal(newGoal);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar kaydedildi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: AppTheme.of(_gender),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('🧑 Cinsiyet Seçimi (test)'),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Erkek'),
                        value: 'male',
                        groupValue: _gender,
                        onChanged: (val) => _changeGender(val),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('Kadın'),
                        value: 'female',
                        groupValue: _gender,
                        onChanged: (val) => _changeGender(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🎨 Tema Seçimi'),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Sistem Teması (Otomatik)'),
                        value: 'system',
                        groupValue: _themeMode,
                        onChanged: (val) => _changeTheme(val),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('Açık Tema (Light)'),
                        value: 'light',
                        groupValue: _themeMode,
                        onChanged: (val) => _changeTheme(val),
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('Koyu Tema (Dark)'),
                        value: 'dark',
                        groupValue: _themeMode,
                        onChanged: (val) => _changeTheme(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🚶 Adım Hedefi'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _stepGoalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Günlük Adım Hedefi',
                        suffixText: 'adım/gün',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) => _saveSettings(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🧩 Aktif Modüllerim (Botlar)'),
                Card(
                  child: Column(
                    children: [
                      _buildBotTile('💊 İlaç Takibi', 'medication_bot'),
                      const Divider(height: 1),
                      _buildBotTile('✅ Rutin Takibi', 'habit_bot'),
                      const Divider(height: 1),
                      _buildBotTile('🏃 Spor & Antrenman', 'sport_bot'),
                      const Divider(height: 1),
                      _buildBotTile('🧪 Takviye / Supplement', 'supplement_bot'),
                      const Divider(height: 1),
                      _buildBotTile('👟 Adım Takibi', 'step_bot'),
                      const Divider(height: 1),
                      _buildBotTile('📊 Değerlendirme / Anket', 'assessment_bot'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🔔 Bildirimler'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('İlaç hatırlatmaları'),
                        value: _medicationReminders,
                        onChanged: (value) async {
                          setState(() => _medicationReminders = value);
                          await _saveSettings();
                          await _syncMedicationReminders(value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Rutin hatırlatmaları'),
                        value: _habitReminders,
                        onChanged: (value) async {
                          setState(() => _habitReminders = value);
                          await _saveSettings();
                          await _syncHabitReminders(value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Spor hatırlatmaları'),
                        value: _sportReminders,
                        onChanged: (value) async {
                          setState(() => _sportReminders = value);
                          await _saveSettings();
                          await _syncSportReminders(value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Supplement hatırlatmaları'),
                        value: _supplementReminders,
                        onChanged: (value) async {
                          setState(() => _supplementReminders = value);
                          await _saveSettings();
                          await _syncSupplementReminders(value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Adım hatırlatmaları'),
                        value: _stepReminders,
                        onChanged: (value) async {
                          setState(() => _stepReminders = value);
                          await _saveSettings();
                          await NotificationService.setStepReminder(value);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_active, color: Colors.amber),
                        title: const Text('Sistem Bildirim İzinlerini Aç'),
                        subtitle: const Text('Xiaomi/MIUI kısıtlamalarını kaldırmak için tıklayın'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          await NotificationService.openNotificationSettings();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('🌐 Backend'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Bağlantı durumu: '),
                            Icon(
                              _backendConnected ? Icons.check_circle : Icons.error,
                              color: _backendConnected ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            Text(
                              _backendConnected ? ' Bağlı' : ' Bağlı değil',
                              style: TextStyle(
                                color: _backendConnected ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('API URL: ${AppConfig.baseUrl}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('📱 Uygulama'),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text('Versiyon'),
                        trailing: Text('1.0.0'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Verileri sıfırla', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          // TODO: Implement data reset
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _syncMedicationReminders(bool enabled) async {
    final data = await _api.getMedications();
    final medications = data.map((json) => Medication.fromJson(json)).toList();
    await NotificationService.setMedicationReminders(enabled, medications);
  }

  Future<void> _syncHabitReminders(bool enabled) async {
    final data = await _api.getHabits();
    final habits = data.map((json) => Habit.fromJson(json)).toList();
    await NotificationService.setHabitReminders(enabled, habits);
  }

  Future<void> _syncSportReminders(bool enabled) async {
    final data = await _api.getSportPlans();
    final plans = data.map((json) => SportPlan.fromJson(json)).toList();
    await NotificationService.setSportReminders(enabled, plans);
  }

  Future<void> _syncSupplementReminders(bool enabled) async {
    final data = await _api.getSupplementPlans();
    final supps = data.map((json) => SupplementPlan.fromJson(json)).toList();
    await NotificationService.setSupplementReminders(enabled, supps);
  }

  Widget _buildBotTile(String title, String botKey) {
    final bool isEnabled = _botPreferences[botKey] ?? false;
    return SwitchListTile(
      title: Text(title),
      value: isEnabled,
      onChanged: (value) async {
        setState(() {
          _botPreferences[botKey] = value;
        });

        if (_backendConnected) {
          final success = await _api.updatePreference(botKey, value);
          if (!success && mounted) {
            setState(() {
              _botPreferences[botKey] = !value;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Modül güncellenirken hata oluştu')),
            );
          }
        }
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.of(_gender),
        ),
      ),
    );
  }
}
