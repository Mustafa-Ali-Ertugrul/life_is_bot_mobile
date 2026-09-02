import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/models/sport_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient sport/supplement integration (MockClient)', () {
    late ApiClient api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = ApiClient();
      api.resetForTest();
      api.setTestToken('test-jwt-token');
    });

    test('getSportPlans parses paginated {items:[]} correctly', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/sport'));
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');
        return http.Response(jsonEncode({
          'items': [
            {'id': 1, 'sport_type': 'Kosu', 'target_hour': 18, 'target_minute': 0, 'days_of_week': '1,3,5', 'is_active': true},
            {'id': 2, 'sport_type': 'Yoga', 'target_hour': 7, 'target_minute': 30, 'days_of_week': '2,4', 'is_active': true},
          ],
          'total': 2
        }), 200);
      });
      api.setTestClient(mock);
      final result = await api.getSportPlans();
      expect(result.length, 2);
      expect(result[0]['sport_type'], 'Kosu');
      expect(SportPlan.fromJson(result[0]).timeText, '18:00');
    });

    test('getSportPlans parses raw list correctly', () async {
      final mock = MockClient((request) async {
        return http.Response(jsonEncode([
          {'id': 3, 'sport_type': 'Pilates', 'target_hour': 19, 'target_minute': 15, 'days_of_week': '1,2,3', 'is_active': true}
        ]), 200);
      });
      api.setTestClient(mock);
      final result = await api.getSportPlans();
      expect(result.length, 1);
      expect(result[0]['sport_type'], 'Pilates');
    });

    test('getSportPlans returns empty on non-200', () async {
      final mock = MockClient((_) async => http.Response('error', 500));
      api.setTestClient(mock);
      final result = await api.getSportPlans();
      expect(result, isEmpty);
    });

    test('createSportPlan sends correct payload and parses response', () async {
      final plan = SportPlan(id: 0, sportType: 'Kosu', targetHour: 18, targetMinute: 0, daysOfWeek: '1,3,5');
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/sport'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sport_type'], 'Kosu');
        expect(body['target_hour'], 18);
        expect(body['days_of_week'], '1,3,5');
        return http.Response(jsonEncode({
          'id': 10, 'sport_type': 'Kosu', 'target_hour': 18, 'target_minute': 0, 'days_of_week': '1,3,5', 'is_active': true
        }), 201);
      });
      api.setTestClient(mock);
      final created = await api.createSportPlan(plan);
      expect(created, isNotNull);
      expect(created!.id, 10);
      expect(created.sportType, 'Kosu');
    });

    test('createSportPlan returns null on failure', () async {
      final mock = MockClient((_) async => http.Response('bad', 400));
      api.setTestClient(mock);
      final result = await api.createSportPlan(SportPlan(id: 0, sportType: 'X', targetHour: 8, targetMinute: 0));
      expect(result, isNull);
    });

    test('deleteSportPlan succeeds on 204', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/sport/5'));
        return http.Response('', 204);
      });
      api.setTestClient(mock);
      expect(await api.deleteSportPlan(5), true);
    });

    test('deleteSportPlan succeeds on 200', () async {
      final mock = MockClient((_) async => http.Response('', 200));
      api.setTestClient(mock);
      expect(await api.deleteSportPlan(7), true);
    });

    test('getSupplementPlans parses paginated correctly', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/supplement'));
        return http.Response(jsonEncode({
          'items': [
            {'id': 1, 'name': 'Whey', 'dose': '30g', 'target_hour': 9, 'target_minute': 0, 'days_of_week': '1,2,3', 'is_active': true}
          ],
          'total': 1
        }), 200);
      });
      api.setTestClient(mock);
      final result = await api.getSupplementPlans();
      expect(result.length, 1);
      expect(result[0]['name'], 'Whey');
    });

    test('createSupplementPlan sends correct payload', () async {
      final body = {'name': 'Kreatin', 'dose': '5g', 'target_hour': 8, 'target_minute': 0, 'days_of_week': '1,3,5'};
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        final sent = jsonDecode(request.body);
        expect(sent['name'], 'Kreatin');
        expect(sent['dose'], '5g');
        return http.Response(jsonEncode({'id': 20, 'name': 'Kreatin', 'dose': '5g', 'target_hour': 8, 'target_minute': 0, 'days_of_week': '1,3,5', 'is_active': true}), 201);
      });
      api.setTestClient(mock);
      final result = await api.createSupplementPlan(body);
      expect(result, isNotNull);
      expect(result!['id'], 20);
    });

    test('deleteSupplementPlan succeeds', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/supplement/3'));
        return http.Response('', 204);
      });
      api.setTestClient(mock);
      expect(await api.deleteSupplementPlan(3), true);
    });

    test('getMonthDays builds correct query and parses response', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/reports/monthly/days'));
        expect(request.url.queryParameters['year'], '2026');
        expect(request.url.queryParameters['month'], '8');
        expect(request.url.queryParameters['bot_key'], 'sport_bot');
        expect(request.headers['Authorization'], 'Bearer test-jwt-token');
        return http.Response(jsonEncode({
          'scheduled_days': ['2026-08-01', '2026-08-03'],
          'completed_days': ['2026-08-01'],
          'year': 2026,
          'month': 8,
          'bot_key': 'sport_bot'
        }), 200);
      });
      api.setTestClient(mock);
      final result = await api.getMonthDays(2026, 8, 'sport_bot');
      expect(result, isNotNull);
      expect(result!['scheduled_days'], hasLength(2));
      expect(result['completed_days'], hasLength(1));
    });

    test('getMonthDays returns null on non-200', () async {
      final mock = MockClient((_) async => http.Response('not found', 404));
      api.setTestClient(mock);
      expect(await api.getMonthDays(2026, 8, 'habit_bot'), isNull);
    });

    test('init fetches token via provisioning key and stores', () async {
      SharedPreferences.setMockInitialValues({});
      api.resetForTest();
      api.setTestProvisioningKey('test-provisioning-key');
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/auth/token'));
        expect(request.headers['X-Provisioning-Key'], isNotEmpty);
        return http.Response(jsonEncode({'access_token': 'new-jwt-123'}), 200);
      });
      api.setTestClient(mock);
      final ok = await api.init();
      expect(ok, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('api_access_token'), 'new-jwt-123');
    });

    test('headers include Authorization only when token set', () async {
      api.resetForTest();
      SharedPreferences.setMockInitialValues({});
      final mockNoAuth = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), false);
        return http.Response(jsonEncode([]), 200);
      });
      api.setTestClient(mockNoAuth);
      await api.getSportPlans();

      api.setTestToken('abc');
      final mockWithAuth = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer abc');
        return http.Response(jsonEncode([]), 200);
      });
      api.setTestClient(mockWithAuth);
      await api.getSportPlans();
    });
  });
}
