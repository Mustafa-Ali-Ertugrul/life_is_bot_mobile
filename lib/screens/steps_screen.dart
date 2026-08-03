// lib/screens/steps_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/database.dart';
import '../services/google_fit_service.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  final DatabaseService _db = DatabaseService();
  final GoogleFitService _googleFit = GoogleFitService();

  final Map<DateTime, int> _weeklySteps = {};
  bool _loading = true;

  final List<String> _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    setState(() => _loading = true);

    // Önce Google Fit'ten senkronize et
    if (await _googleFit.isAvailable()) {
      await _googleFit.syncSteps();
    }

    // Local DB'den haftalık verileri al
    final weekly = await _db.getWeeklySteps();

    // Eksik günleri 0 ile doldur
    final now = DateTime.now();
    _weeklySteps.clear();
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      _weeklySteps[date] = weekly[date] ?? 0;
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  int get _totalSteps => _weeklySteps.values.fold(0, (sum, steps) => sum + steps);
  double get _averageSteps => _weeklySteps.isEmpty ? 0 : _totalSteps / _weeklySteps.length;
  int get _maxSteps => _weeklySteps.isEmpty ? 0 : _weeklySteps.values.reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adım Takibi'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSteps,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSteps,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  _buildDailyList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Toplam',
            '$_totalSteps',
            Icons.directions_walk,
            Colors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Ortalama',
            '${_averageSteps.round()}',
            Icons.trending_up,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'En İyi',
            '$_maxSteps',
            Icons.emoji_events,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Haftalık Adımlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_maxSteps.toDouble() * 1.2 > 0) ? _maxSteps.toDouble() * 1.2 : 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_dayNames[(DateTime.now().subtract(Duration(days: 6 - groupIndex)).weekday + 6) % 7]}\n${rod.toY.toInt()} adım',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int dayIdx = (DateTime.now().subtract(Duration(days: 6 - value.toInt())).weekday + 6) % 7;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _dayNames[dayIdx],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: _weeklySteps.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final steps = entry.value.value;
                    final isToday = index == _weeklySteps.length - 1;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: steps.toDouble(),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                          color: isToday ? Colors.teal : Colors.teal.withOpacity(0.5),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyList() {
    final entries = _weeklySteps.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📅 Günlük Detay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...entries.reversed.map((entry) {
              final date = entry.key;
              final steps = entry.value;
              final now = DateTime.now();
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.teal : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday ? 'Bugün' : _dayNames[(date.weekday + 6) % 7],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${date.day}.${date.month}.${date.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$steps adım',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: steps >= 10000 ? Colors.green : Colors.black87,
                      ),
                    ),
                    if (steps >= 10000)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
