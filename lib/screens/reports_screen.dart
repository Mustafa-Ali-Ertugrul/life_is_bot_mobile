// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import 'habits_screen.dart';
import 'medications_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;

  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;
  Map<String, dynamic>? _monthlyReport;
  Map<String, dynamic>? _streak;
  bool _loading = true;
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReports();
    AppTheme.loadGender().then((g) {
      if (mounted) setState(() => _gender = g);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _api.getDailyReport(),
      _api.getWeeklyReport(),
      _api.getMonthlyReport(),
      _api.getStreak(),
    ]);

    setState(() {
      _dailyReport = results[0];
      _weeklyReport = results[1];
      _monthlyReport = results[2];
      _streak = results[3];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        backgroundColor: AppTheme.of(_gender),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Günlük'),
            Tab(icon: Icon(Icons.date_range), text: 'Haftalık'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Aylık'),
            Tab(icon: Icon(Icons.local_fire_department), text: 'Streak'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyTab(),
                _buildWeeklyTab(),
                _buildMonthlyTab(),
                _buildStreakTab(),
              ],
            ),
    );
  }

  Widget _buildDailyTab() {
    if (_dailyReport == null) {
      return const Center(child: Text('Rapor verisi yok'));
    }

    final total = (_dailyReport!['total'] ?? 0).toInt();
    final completed = (_dailyReport!['completed'] ?? 0).toInt();
    final missed = (_dailyReport!['missed'] ?? 0).toInt();
    final unanswered = (_dailyReport!['unanswered'] ?? 0).toInt();
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    if (total == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildEmptyStateCard()],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProgressCard('Bugünkü İlerleme', rate, completed, total),
        const SizedBox(height: 16),
        _buildStatRow('✅ Tamamlanan', completed, Colors.green),
        _buildStatRow('❌ Kaçırılan', missed, Colors.red),
        _buildStatRow('⏳ Yanıtlanmayan', unanswered, Colors.orange),
        const SizedBox(height: 16),
        if (_dailyReport!['completed_items'] != null)
          _buildItemList('Tamamlananlar', _dailyReport!['completed_items']),
        if (_dailyReport!['missed_items'] != null)
          _buildItemList('Kaçırılanlar', _dailyReport!['missed_items']),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    if (_weeklyReport == null) {
      return const Center(child: Text('Rapor verisi yok'));
    }

    final total = (_weeklyReport!['total'] ?? 0).toInt();
    final completed = (_weeklyReport!['completed'] ?? 0).toInt();
    final rate = (_weeklyReport!['compliance_rate'] ?? 0).toInt();
    final weekStart = _weeklyReport!['week_start'] ?? '';
    final weekEnd = _weeklyReport!['week_end'] ?? '';

    if (total == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildEmptyStateCard()],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📅 Hafta Aralığı',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('$weekStart - $weekEnd'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildProgressCard('Haftalık İlerleme', rate, completed, total),
        const SizedBox(height: 16),
        _buildStatRow('✅ Tamamlanan', completed, Colors.green),
        _buildStatRow('❌ Kaçırılan', (_weeklyReport!['missed'] ?? 0).toInt(), Colors.red),
        _buildStatRow('⏳ Yanıtlanmayan', (_weeklyReport!['unanswered'] ?? 0).toInt(), Colors.orange),
      ],
    );
  }

  Widget _buildMonthlyTab() {
    if (_monthlyReport == null) {
      return const Center(child: Text('Rapor verisi yok'));
    }

    final total = (_monthlyReport!['total'] ?? 0).toInt();
    final completed = (_monthlyReport!['total_completed'] ?? 0).toInt();
    final rate = (_monthlyReport!['completion_rate'] ?? 0).toInt();

    if (total == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildEmptyStateCard()],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProgressCard('Aylık İlerleme', rate, completed, total),
        const SizedBox(height: 16),
        _buildStatRow('✅ Tamamlanan', completed, Colors.green),
        _buildStatRow('❌ Kaçırılan', (_monthlyReport!['total_missed'] ?? 0).toInt(), Colors.red),
        _buildStatRow('⏳ Bekleyen', (_monthlyReport!['total_pending'] ?? 0).toInt(), Colors.orange),
      ],
    );
  }

  Widget _buildStreakTab() {
    if (_streak == null) {
      return const Center(child: Text('Streak verisi yok'));
    }

    final current = (_streak!['current'] ?? 0).toInt();
    final longest = (_streak!['longest'] ?? 0).toInt();
    final todayCompleted = _streak!['today_completed'] ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.local_fire_department, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  '🔥 $current gün',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Mevcut Seri',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  '🏆 $longest gün',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'En Uzun Seri',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              todayCompleted ? Icons.check_circle : Icons.pending,
              color: todayCompleted ? Colors.green : Colors.orange,
              size: 40,
            ),
            title: Text(todayCompleted ? 'Bugün tamamlandı!' : 'Bugün henüz tamamlanmadı'),
            subtitle: Text(
              todayCompleted
                  ? 'Seri devam ediyor 🔥'
                  : 'Seriyi korumak için bugünü tamamla!',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 64, color: AppTheme.of(_gender)),
            const SizedBox(height: 12),
            const Text(
              'Henüz veri yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bugünkü ilk rutinini tamamla, raporun burada hayat bulsun!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HabitsScreen()),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Rutin Ekle'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MedicationsScreen()),
                  ),
                  icon: const Icon(Icons.medication),
                  label: const Text('İlaç Ekle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, int rate, int completed, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: rate / 100,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rate >= 80 ? Colors.green : AppTheme.of(_gender),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '%$rate',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completed / $total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            )),
          ],
        ),
      ),
    );
  }
}
