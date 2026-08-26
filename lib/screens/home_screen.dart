import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_fit_service.dart';
import '../core/database.dart';
import '../core/api_client.dart';
import '../core/app_navigator.dart';
import '../core/theme.dart';
import '../models/habit.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import 'habits_screen.dart';
import 'medications_screen.dart';
import 'sport_screen.dart';
import 'steps_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GoogleFitService _googleFit = GoogleFitService();
  final DatabaseService _db = DatabaseService();
  final ApiClient _api = ApiClient();

  late final TabController _tabController;

  int _todaySteps = 0;
  int _stepGoal = 10000;
  bool _loading = true;
  bool _googleFitAvailable = false;
  bool _backendConnected = false;
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
    _tabController = TabController(length: 4, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    NotificationService.consumeLaunchPayload().then((payload) {
      if (payload != null) AppNavigator.openForPayload(payload);
    });
    await _initGoogleFit();
    await _loadBackendData();
    setState(() => _loading = false);
  }

  Future<void> _initGoogleFit() async {
    try {
      _googleFitAvailable = await _googleFit
          .isAvailable()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);

      if (_googleFitAvailable) {
        await _googleFit
            .requestPermission()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        try {
          await _refreshSteps();
        } catch (e) {
          debugPrint('❌ Refresh steps error: $e');
          _todaySteps = await _db.getTodaySteps();
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Google Fit init error: $e');
      _googleFitAvailable = false;
    }
    _todaySteps = await _db.getTodaySteps();
  }

  Future<void> _loadBackendData() async {
    final prefs = await SharedPreferences.getInstance();
    final userGender = prefs.getString('user_gender') ?? 'male';
    if (mounted) {
      setState(() => _gender = userGender);
    }

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

      // Yerel bildirim zamanlamalarını güncel saat dilimiyle senkronla
      if (prefs.getBool('medication_reminders') ?? true) {
        await NotificationService.setMedicationReminders(
          true,
          meds.map((m) => Medication.fromJson(m)).toList(),
        );
      }
      if (prefs.getBool('habit_reminders') ?? true) {
        await NotificationService.setHabitReminders(
          true,
          habits.map((h) => Habit.fromJson(h)).toList(),
        );
      }
      if (prefs.getBool('step_reminders') ?? true) {
        await NotificationService.setStepReminder(true);
      }

      // Streak bilgisini al
      final streak = await _api.getStreak();

      // Adım hedefini al
      final goal = await _api.getStepGoal();

      if (mounted) {
        setState(() {
          _botPreferences = newPrefs;
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

  String _getRunnerAsset() {
    final prefix = _gender == 'female' ? 'runner_female_phase' : 'runner_phase';
    if (_currentStreak >= 30) {
      return 'assets/images/${prefix}_4.gif';
    } else if (_currentStreak >= 15) {
      return 'assets/images/${prefix}_3.gif';
    } else if (_currentStreak >= 7) {
      return 'assets/images/${prefix}_2.gif';
    } else {
      return 'assets/images/${prefix}_1.gif';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Is Bot'),
        backgroundColor: AppTheme.of(_gender),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Koşu', icon: Icon(Icons.directions_run)),
            Tab(text: 'Spor', icon: Icon(Icons.fitness_center)),
            Tab(text: 'Rutin', icon: Icon(Icons.check_circle)),
            Tab(text: 'İlaç', icon: Icon(Icons.medication)),
          ],
        ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRunningTab(),
                const SportScreen(embedded: true),
                const HabitsScreen(embedded: true),
                const MedicationsScreen(embedded: true),
              ],
            ),
    );
  }

  Widget _buildRunningTab() {
    return RefreshIndicator(
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
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Widget _buildStepCard() {
    final themeColor = _gender == 'female' ? AppTheme.femaleColor : AppTheme.maleColor;
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              // Content Box (Ring Gauge + Divider + Runner Illustration)
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Gauge & Metrics Area
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Circular Progress Dial
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox.expand(
                                      child: CircularProgressIndicator(
                                        value: _progress,
                                        strokeWidth: 12,
                                        strokeCap: StrokeCap.round,
                                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Hedef: $formattedGoal',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Adım',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Vertical Divider Line
                      Container(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                      ),

                      // Right Runner Illustration Area (Bütün Ayaklar Kırpılmadan Kadrajda)
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Image.asset(
                              _getRunnerAsset(),
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
                      ),
                    ],
                  ),
                ),
              ),
              if (!_googleFitAvailable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Google Fit / Health Connect bu cihazda yok. Adımlar manuel kayıtlardan okunur.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
}
