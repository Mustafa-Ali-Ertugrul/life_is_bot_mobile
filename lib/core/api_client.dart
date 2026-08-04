// lib/core/api_client.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import '../models/habit.dart';
import '../models/medication.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();

  /// Ortak header'lar
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AppConfig.apiKey}',
  };

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
}
