import 'package:flutter/material.dart';
import '../services/google_fit_service.dart';
import '../core/database.dart';
import '../core/api_client.dart';
import 'habits_screen.dart';
import 'medications_screen.dart';

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
    // Backend bağlı mı?
    _backendConnected = await _api.checkHealth();

    if (_backendConnected) {
      // İlaç ve rutin sayılarını al
      final meds = await _api.getMedications();
      final habits = await _api.getHabits();

      // Streak bilgisini al
      final streak = await _api.getStreak();

      // Adım hedefini al
      final goal = await _api.getStepGoal();

      if (mounted) {
        setState(() {
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
        backgroundColor: Colors.teal,
        actions: [
          // Backend bağlantı durumu
          IconButton(
            icon: Icon(
              _backendConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _backendConnected ? Colors.green : Colors.grey,
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
                  _buildStepCard(),
                  const SizedBox(height: 16),
                  _buildStreakCard(),
                  const SizedBox(height: 16),
                  _buildMedicationCard(),
                  const SizedBox(height: 16),
                  _buildHabitCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStepCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '🚶 Bugünkü Adımlar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progress >= 1.0 ? Colors.green : Colors.teal,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_todaySteps',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/ $_stepGoal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            ? const Icon(Icons.chevron_right)
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
