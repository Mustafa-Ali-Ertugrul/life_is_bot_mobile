// lib/core/api_client.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import '../models/habit.dart';
import '../models/medication.dart';
import '../models/sport_plan.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  http.Client _client = http.Client();
  static const String _tokenKey = 'api_access_token';
  String? _accessToken;

  @visibleForTesting
  void setTestClient(http.Client client) => _client = client;

  @visibleForTesting
  void setTestToken(String token) => _accessToken = token;

  @visibleForTesting
  void resetForTest() {
    _accessToken = null;
    _client = http.Client();
  }

  /// Önbellekteki token'ı yükle ve provisioning key ile taze JWT al
  Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (stored != null && stored.isNotEmpty) {
      _accessToken = stored;
    }
    final ok = await _fetchToken(prefs);
    return ok || _accessToken != null;
  }

  Future<bool> _fetchToken(SharedPreferences prefs) async {
    if (AppConfig.provisioningKey.isEmpty) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/auth/token'),
            headers: {'X-Provisioning-Key': AppConfig.provisioningKey},
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));
      if (response.statusCode != 200) {
        debugPrint('⚠️ Token fetch failed: ${response.statusCode}');
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) return false;
      _accessToken = token;
      await prefs.setString(_tokenKey, token);
      return true;
    } catch (e) {
      debugPrint('❌ Token fetch error: $e');
      return false;
    }
  }

  /// Ortak header'lar
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null && _accessToken!.isNotEmpty)
      'Authorization': 'Bearer $_accessToken',
  };

  /// Bildirim aksiyon yanıtı (İçtim/Yapıldı) — backend event pipeline'ına yazar
  Future<bool> submitResponse({
    required String relatedType,
    required int relatedId,
    required String response,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/responses'),
            headers: _headers,
            body: jsonEncode({
              'related_type': relatedType,
              'related_id': relatedId,
              'response': response,
            }),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('❌ submitResponse error: $e');
      return false;
    }
  }

  /// Health check - backend bağlı mı?
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/health'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Backend health check failed: $e');
      return false;
    }
  }

  /// İlaç listesi
  Future<List<Map<String, dynamic>>> getMedications() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/medications'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // PaginatedResponse formatı: {"items": [...], "total": N}
        if (data is Map && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
        return List<Map<String, dynamic>>.from(data);
      }
      debugPrint('⚠️ Medications API error: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching medications: $e');
      return [];
    }
  }

  /// İlaç ekle
  Future<Medication?> createMedication(Medication medication) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/medications'),
            headers: _headers,
            body: jsonEncode(medication.toJson()),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Medication.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating medication: $e');
      return null;
    }
  }

  /// İlaç sil
  Future<bool> deleteMedication(int id) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${AppConfig.baseUrl}/medications/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');
      return false;
    }
  }

  /// Rutin listesi
  Future<List<Map<String, dynamic>>> getHabits() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/habits'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
        return List<Map<String, dynamic>>.from(data);
      }
      debugPrint('⚠️ Habits API error: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching habits: $e');
      return [];
    }
  }

  /// Rutin ekle
  Future<Habit?> createHabit(Habit habit) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/habits'),
            headers: _headers,
            body: jsonEncode(habit.toJson()),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Habit.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating habit: $e');
      return null;
    }
  }

  /// Rutin güncelle
  Future<Habit?> updateHabit(int id, Habit habit) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${AppConfig.baseUrl}/habits/$id'),
            headers: _headers,
            body: jsonEncode(habit.toJson()),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return Habit.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error updating habit: $e');
      return null;
    }
  }

  /// Rutin sil
  Future<bool> deleteHabit(int id) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${AppConfig.baseUrl}/habits/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('❌ Error deleting habit: $e');
      return false;
    }
  }

  /// Spor planı listesi
  Future<List<Map<String, dynamic>>> getSportPlans() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/sport'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // PaginatedResponse formatı: {"items": [...], "total": N}
        if (data is Map && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
        return List<Map<String, dynamic>>.from(data);
      }
      debugPrint('⚠️ Sport API error: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching sport plans: $e');
      return [];
    }
  }

  /// Spor planı ekle
  Future<SportPlan?> createSportPlan(SportPlan plan) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/sport'),
            headers: _headers,
            body: jsonEncode(plan.toJson()),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return SportPlan.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating sport plan: $e');
      return null;
    }
  }

  /// Spor planı sil (backend soft-delete: is_active=false)
  Future<bool> deleteSportPlan(int id) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${AppConfig.baseUrl}/sport/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('❌ Error deleting sport plan: $e');
      return false;
    }
  }

  /// Supplement (takviye) listesi
  Future<List<Map<String, dynamic>>> getSupplementPlans() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/supplement'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching supplement plans: $e');
      return [];
    }
  }

  /// Supplement (takviye) ekle
  Future<Map<String, dynamic>?> createSupplementPlan(Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/supplement'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error creating supplement plan: $e');
      return null;
    }
  }

  /// Supplement (takviye) sil
  Future<bool> deleteSupplementPlan(int id) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${AppConfig.baseUrl}/supplement/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('❌ Error deleting supplement plan: $e');
      return false;
    }
  }

  /// Adım hedefini al
  Future<int> getStepGoal() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/step/settings'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['daily_target'] ?? data['daily_goal'] ?? 10000;
      }
      return 10000;
    } catch (e) {
      debugPrint('❌ Error fetching step goal: $e');
      return 10000;
    }
  }

  /// Adım hedefini güncelle
  Future<bool> updateStepGoal(int goal) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('${AppConfig.baseUrl}/step/settings'),
            headers: _headers,
            body: jsonEncode({'daily_target': goal}),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error updating step goal: $e');
      return false;
    }
  }

  /// Günlük rapor
  Future<Map<String, dynamic>?> getDailyReport() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/reports/daily'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching daily report: $e');
      return null;
    }
  }

  /// Haftalık rapor
  Future<Map<String, dynamic>?> getWeeklyReport() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/reports/weekly'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching weekly report: $e');
      return null;
    }
  }

  /// Aylık rapor
  Future<Map<String, dynamic>?> getMonthlyReport() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/reports/monthly'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching monthly report: $e');
      return null;
    }
  }

  /// Aylık gün-gün rapor (bot bazında): planlı/tamamlanmış günler
  Future<Map<String, dynamic>?> getMonthDays(
    int year,
    int month,
    String botKey,
  ) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/reports/monthly/days',
      ).replace(
        queryParameters: {
          'year': '$year',
          'month': '$month',
          'bot_key': botKey,
        },
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching month days: $e');
      return null;
    }
  }

  /// Streak bilgisi
  Future<Map<String, dynamic>?> getStreak() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/reports/streak'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching streak: $e');
      return null;
    }
  }

  /// Adımları backend'e gönder
  Future<bool> postSteps(int steps, DateTime date) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/step/logs'),
            headers: _headers,
            body: jsonEncode({
              'steps': steps,
              'log_date': date.toIso8601String().split('T')[0],
            }),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error posting steps: $e');
      return false;
    }
  }

  /// Bot/Modül tercihlerini getir
  Future<List<Map<String, dynamic>>> getPreferences() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/preferences'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching preferences: $e');
      return [];
    }
  }

  /// Bot/Modül aç/kapat
  Future<bool> updatePreference(String botKey, bool enabled) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('${AppConfig.baseUrl}/preferences/$botKey'),
            headers: _headers,
            body: jsonEncode({'enabled': enabled}),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error updating preference $botKey: $e');
      return false;
    }
  }

  /// Onboarding durumunu getir (sıradaki soru dahil)
  Future<Map<String, dynamic>?> getOnboardingStatus() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/onboarding'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching onboarding status: $e');
      return null;
    }
  }

  /// Onboarding cevabı gönder; sonraki soru veya sonucu döndür
  Future<Map<String, dynamic>?> submitOnboardingAnswer(
    String questionKey,
    String answerValue,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/onboarding/answer'),
            headers: _headers,
            body: jsonEncode({
              'question_key': questionKey,
              'answer_value': answerValue,
            }),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error submitting onboarding answer: $e');
      return null;
    }
  }

  /// Onboarding testi atla
  Future<bool> skipOnboarding() async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}/onboarding/skip'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error skipping onboarding: $e');
      return false;
    }
  }
}
