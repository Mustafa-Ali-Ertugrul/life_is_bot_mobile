import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/config.dart';

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
  bool _stepReminders = true;
  bool _backendConnected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final goal = await _api.getStepGoal();
    _backendConnected = await _api.checkHealth();

    setState(() {
      _stepGoalController.text = goal.toString();
      _medicationReminders = prefs.getBool('medication_reminders') ?? true;
      _habitReminders = prefs.getBool('habit_reminders') ?? true;
      _stepReminders = prefs.getBool('step_reminders') ?? true;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newGoal = int.tryParse(_stepGoalController.text) ?? 10000;

    await prefs.setBool('medication_reminders', _medicationReminders);
    await prefs.setBool('habit_reminders', _habitReminders);
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
        backgroundColor: Colors.teal,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                _buildSectionTitle('🔔 Bildirimler'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('İlaç hatırlatmaları'),
                        value: _medicationReminders,
                        onChanged: (value) {
                          setState(() => _medicationReminders = value);
                          _saveSettings();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Rutin hatırlatmaları'),
                        value: _habitReminders,
                        onChanged: (value) {
                          setState(() => _habitReminders = value);
                          _saveSettings();
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Adım hatırlatmaları'),
                        value: _stepReminders,
                        onChanged: (value) {
                          setState(() => _stepReminders = value);
                          _saveSettings();
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }
}
