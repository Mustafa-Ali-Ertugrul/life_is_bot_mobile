import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_fit_service.dart';
import '../core/database.dart';
import '../core/api_client.dart';
import 'habits_screen.dart';
import 'medications_screen.dart';
import 'steps_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleFitService _googleFit = GoogleFitService();
  final DatabaseService _db = DatabaseService();
  final ApiClient _api = ApiClient();

  int _todaySteps = 0;
  int _stepGoal = 10000;
  bool _loading = true;
  bool _googleFitAvailable = false;
  bool _backendConnected = false;
  int _medicationCount = 0;
  int _habitCount = 0;
  int _currentStreak = 0;
  String _gender = 'male'; // 'male' -> Turkuaz, 'female' -> Yeşil

  // Active module state map
  Map<String, bool> _botPreferences = {
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
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    await _initGoogleFit();
    await _loadBackendData();
    setState(() => _loading = false);
  }

  Future<void> _initGoogleFit() async {
    _googleFitAvailable = await _googleFit.isAvailable();

    if (_googleFitAvailable) {
      await _googleFit.requestPermission();
      await _refreshSteps();
    } else {
      _todaySteps = await _db.getTodaySteps();
    }
  }

  Future<void> _loadBackendData() async {
    final prefs = await SharedPreferences.getInstance();
    final userGender = prefs.getString('user_gender') ?? 'male';

    // Backend bağlı mı?
    _backendConnected = await _api.checkHealth();

    if (_backendConnected) {
      // Modül tercihlerini çek
      final preferences = await _api.getPreferences();
      final Map<String, bool> newPrefs = Map.from(_botPreferences);
      for (var pref in preferences) {
        final key = pref['bot_key'] as String?;
        final enabled = pref['enabled'] as bool?;
        if (key != null && enabled != null) {
          newPrefs[key] = enabled;
        }
      }

      // İlaç ve rutin sayılarını al
      final meds = await _api.getMedications();
      final habits = await _api.getHabits();

      // Streak bilgisini al
      final streak = await _api.getStreak();

      // Adım hedefini al
      final goal = await _api.getStepGoal();

      if (mounted) {
        setState(() {
          _gender = userGender;
          _botPreferences = newPrefs;
          _medicationCount = meds.length;
          _habitCount = habits.length;
          _currentStreak = streak?['current'] ?? 0;
          _stepGoal = goal;
        });
      }
    }
  }

  Future<void> _refreshSteps() async {
    if (!_googleFitAvailable) return;

    final steps = await _googleFit.getTodaySteps();
    await _db.saveSteps(steps: steps, date: DateTime.now());

    if (mounted) {
      setState(() {
        _todaySteps = steps;
      });
    }

    // Backend'e gönder
    if (_backendConnected) {
      await _api.postSteps(steps, DateTime.now());
    }
  }

  double get _progress => (_todaySteps / _stepGoal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Is Bot'),
        backgroundColor: _gender == 'female' ? Colors.green : Colors.teal,
        actions: [
          // Raporlar butonu
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
            tooltip: 'Raporlar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadBackendData());
            },
            tooltip: 'Ayarlar',
          ),
          // Backend bağlantı durumu
          IconButton(
            icon: Icon(
              _backendConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _backendConnected ? Colors.white : Colors.grey,
            ),
            onPressed: _loadBackendData,
            tooltip: _backendConnected ? 'Backend bağlı' : 'Backend bağlı değil',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _refreshSteps();
              await _loadBackendData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshSteps();
                await _loadBackendData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_botPreferences['step_bot'] ?? true) ...[
                    _buildStepCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildStreakCard(),
                  if (_botPreferences['medication_bot'] ?? true) ...[
                    const SizedBox(height: 16),
                    _buildMedicationCard(),
                  ],
                  if (_botPreferences['habit_bot'] ?? true) ...[
                    const SizedBox(height: 16),
                    _buildHabitCard(),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Widget _buildStepCard() {
    final themeColor = _gender == 'female' ? Colors.green : const Color(0xFF1E406B);
    final percentage = (_progress * 100).toStringAsFixed(1);
    final formattedSteps = _formatNumber(_todaySteps);
    final formattedGoal = _formatNumber(_stepGoal);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StepsScreen()),
          ).then((_) => _refreshSteps());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Günlük Adım Sayısı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              // Content Box (Ring Gauge + Divider + Runner Illustration)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    // Left Gauge & Metrics Area
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Circular Progress Dial
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: CircularProgressIndicator(
                                    value: _progress,
                                    strokeWidth: 14,
                                    backgroundColor: Colors.blueGrey[100],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _progress >= 1.0 ? Colors.green : themeColor,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formattedSteps,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[900],
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hedef: $formattedGoal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Adım',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Percentage text at bottom right of the dial
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '$percentage%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vertical Divider Line
                    Container(
                      height: 140,
                      width: 1,
                      color: Colors.grey[350],
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),

                    // Right Runner Illustration Area
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: Image.asset(
                          _gender == 'female'
                              ? 'assets/images/runner_female.png'
                              : 'assets/images/runner_male.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.directions_run,
                              size: 90,
                              color: themeColor,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_googleFitAvailable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Google Fit yüklü değil. Emulator'da test edilemez.",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_fire_department, color: Colors.orange, size: 40),
        title: const Text(
          'Seri',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_backendConnected
            ? '$_currentStreak gün ardışık tamamlama'
            : 'Backend bağlı değil'),
        trailing: _backendConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cloud_off, color: Colors.grey),
      ),
    );
  }

  Widget _buildMedicationCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.medication, color: Colors.red, size: 40),
        title: const Text(
          'İlaç Takibi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_backendConnected
            ? '$_medicationCount ilaç kayıtlı'
            : 'Backend bağlı değil'),
        trailing: _backendConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cloud_off, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MedicationsScreen()),
          ).then((_) => _loadBackendData());
        },
      ),
    );
  }

  Widget _buildHabitCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text(
          'Rutin Takibi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_backendConnected
            ? '$_habitCount rutin kayıtlı'
            : 'Backend bağlı değil'),
        trailing: _backendConnected
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.cloud_off, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitsScreen()),
          ).then((_) => _loadBackendData());
        },
      ),
    );
  }
}
