import 'package:flutter/material.dart';
import '../services/google_fit_service.dart';
import '../core/database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleFitService _googleFit = GoogleFitService();
  final DatabaseService _db = DatabaseService();

  int _todaySteps = 0;
  int _stepGoal = 10000;
  bool _loading = true;
  bool _googleFitAvailable = false;

  @override
  void initState() {
    super.initState();
    _initGoogleFit();
  }

  Future<void> _initGoogleFit() async {
    setState(() => _loading = true);

    // Google Fit yüklü mü?
    _googleFitAvailable = await _googleFit.isAvailable();

    if (_googleFitAvailable) {
      // Permission iste
      await _googleFit.requestPermission();

      // Bugünkü adımları al
      await _refreshSteps();
    } else {
      // Local DB'den al
      _todaySteps = await _db.getTodaySteps();
    }

    setState(() => _loading = false);
  }

  Future<void> _refreshSteps() async {
    if (!_googleFitAvailable) return;

    final steps = await _googleFit.getTodaySteps();
    await _db.saveSteps(steps: steps, date: DateTime.now());

    setState(() {
      _todaySteps = steps;
    });
  }

  double get _progress => (_todaySteps / _stepGoal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Is Bot'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSteps,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshSteps,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStepCard(),
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

  Widget _buildMedicationCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.medication, color: Colors.red, size: 40),
        title: const Text(
          'İlaç Takibi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('2 ilaç bugün alınacak'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to medications screen
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
        subtitle: const Text('3/5 rutin tamamlandı'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to habits screen
        },
      ),
    );
  }
}
