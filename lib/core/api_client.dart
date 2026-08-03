// lib/core/api_client.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

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

  /// Adım hedefini al
  Future<int> getStepGoal() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}/steps/settings'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['daily_goal'] ?? 10000;
      }
      return 10000;
    } catch (e) {
      debugPrint('❌ Error fetching step goal: $e');
      return 10000;
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
            Uri.parse('${AppConfig.baseUrl}/steps'),
            headers: _headers,
            body: jsonEncode({
              'steps': steps,
              'date': date.toIso8601String().split('T')[0],
            }),
          )
          .timeout(const Duration(seconds: AppConfig.timeoutSeconds));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error posting steps: $e');
      return false;
    }
  }
}
