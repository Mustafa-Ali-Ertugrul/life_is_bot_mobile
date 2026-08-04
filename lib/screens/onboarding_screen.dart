import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _numberController = TextEditingController();

  Map<String, dynamic>? _question;
  Map<String, dynamic>? _result;
  Set<String> _multiSelection = {};
  String _genderAnswer = '';
  bool _busy = false;
  bool _error = false;

  static const Map<String, String> _profileLabels = {
    'chronic': 'Kronik Sağlık Profili',
    'athlete': 'Aktif / Sporcu Profili',
    'mixed': 'Karma Profil',
    'general': 'Genel Profil',
  };

  static const Map<String, String> _botLabels = {
    'medication_bot': '💊 İlaç Takibi',
    'habit_bot': '✅ Rutin Takibi',
    'sport_bot': '🏃 Spor & Antrenman',
    'supplement_bot': '🧪 Takviye / Supplement',
    'step_bot': '👟 Adım Takibi',
    'assessment_bot': '📊 Değerlendirme / Anket',
  };

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _api.getOnboardingStatus();
    if (status == null) {
      await _enterApp();
      return;
    }
    if (status['completed'] == true ||
        status['skipped'] == true ||
        status['question'] == null) {
      await _enterApp();
      return;
    }
    setState(() {
      _question = Map<String, dynamic>.from(status['question'] as Map);
    });
  }

  Future<void> _enterApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _submit(String value) async {
    if (_busy || _question == null) return;
    final key = _question!['key'] as String;
    setState(() {
      _busy = true;
      _error = false;
    });

    if (key == 'a1_gender') {
      _genderAnswer = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'user_gender',
        value == 'Kadın' ? 'female' : 'male',
      );
    }

    final res = await _api.submitOnboardingAnswer(key, value);
    if (res == null) {
      setState(() {
        _busy = false;
        _error = true;
      });
      return;
    }

    _numberController.clear();
    _multiSelection = {};

    if (res['done'] == true) {
      await _applyGenderTheme();
      setState(() {
        _busy = false;
        _question = null;
        _result = res['result'] == null
            ? null
            : Map<String, dynamic>.from(res['result'] as Map);
      });
      return;
    }

    setState(() {
      _busy = false;
      _question = Map<String, dynamic>.from(res['next'] as Map);
    });
  }

  Future<void> _applyGenderTheme() async {
    if (_genderAnswer.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'user_gender',
      _genderAnswer == 'Kadın' ? 'female' : 'male',
    );
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    await _api.skipOnboarding();
    await _enterApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Is Bot'),
        backgroundColor: AppTheme.maleColor,
        actions: [
          TextButton(
            onPressed: _busy ? null : _skip,
            child: const Text('Testi Atla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _busy && _question == null && _result == null
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildCompletion()
              : _question == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final index = _question!['index'] as int;
    final total = _question!['total'] as int;
    final type = _question!['question_type'] as String;
    final text = _question!['text'] as String;
    final options = (_question!['options'] as List).cast<String>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Soru ${index + 1} / $total',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.maleColor),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (index + 1) / total, backgroundColor: Colors.grey.shade300),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Card(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (type == 'number')
            _buildNumberInput()
          else if (type == 'multi')
            _buildMultiChoice(options)
          else
            _buildOptions(options),
          if (_error)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Cevap gönderilemedi. Bağlantıyı kontrol edip tekrar deneyin.',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptions(List<String> options) {
    return Column(
      children: [
        for (final option in options) ...[
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _submit(option),
              child: Text(option, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMultiChoice(List<String> options) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: _multiSelection.contains(option),
                  onSelected: _busy
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _multiSelection.add(option);
                            } else {
                              _multiSelection.remove(option);
                            }
                          });
                        },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed:
                (_busy || _multiSelection.isEmpty)
                    ? null
                    : () => _submit((_multiSelection.toList()..sort()).join(',')),
            child: const Text('Onayla', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput() {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'örn: 8000',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final preset in ['5000', '8000', '10000'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _submit(preset),
                    child: Text(preset),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy
                ? null
                : () {
                    if (_numberController.text.trim().isEmpty) return;
                    _submit(_numberController.text.trim());
                  },
            child: const Text('Gönder', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletion() {
    final profileType = _result!['profile_type'] as String;
    final enabledBots = (_result!['enabled_bots'] as List).cast<String>();
    final stepGoal = _result!['step_goal'] as int?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.celebration, size: 64, color: AppTheme.maleColor),
        const SizedBox(height: 16),
        const Text(
          'Test Tamamlandı!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Profiliniz: ${_profileLabels[profileType] ?? profileType}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: AppTheme.maleColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        const Text(
          'Size göre aktif edilen modüller:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final bot in enabledBots)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(_botLabels[bot] ?? bot),
                ),
            ],
          ),
        ),
        if (stepGoal != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_walk, color: AppTheme.maleColor),
              title: Text('Günlük adım hedefi: $stepGoal'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _enterApp,
            child: const Text('Ana Ekrana Geç', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
