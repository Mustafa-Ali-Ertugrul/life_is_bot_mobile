// test/auth_retry_regression_test.dart
//
// Bu dosya 2026-09 oturumunda review'da bulunan bug'ları kalıcı olarak
// kapatır. Her test bir GERÇEK bug'ı doğum anında yakalar:
//   1) 401 retry retry isteğinde YENİ token'ı göndermeli
//   2) /auth/token 401 dönerse sonsuz döngü OLMAMALI
//   3) getMedications hata bayrağı (groupFailed) sadece kendi grubunu etkilemeli
//   4) bant çakışmaları (NotificationIds) imkânsız olmalı
// Ayrıca retry'nin yalnızca 401'de tetiklendiğini de kilitler.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/core/notification_ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('401 retry regression (bug: retry eski token ile gidiyordu)', () {
    late ApiClient api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = ApiClient();
      api.resetForTest();
      api.setTestProvisioningKey('test-provisioning-key');
      api.setTestToken('stale-token');
    });

    test('retry isteginde YENI token gider, 200 donen yanit ulasilir', () async {
      var sportCallCount = 0;
      var tokenCallCount = 0;
      var seenAuthHeaders = <String?>[];

      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/auth/token')) {
          tokenCallCount++;
          return http.Response(jsonEncode({'access_token': 'fresh-token'}), 200);
        }
        if (request.url.path.endsWith('/sport')) {
          sportCallCount++;
          seenAuthHeaders.add(request.headers['Authorization']);
          // Ilk istek 401 (stale token), retry 200
          if (sportCallCount == 1) {
            return http.Response('unauthorized', 401);
          }
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('not found', 404);
      });
      api.setTestClient(mock);

      final result = await api.getSportPlans();

      expect(result, isEmpty); // bos liste: retry basarili oldu, veri yok
      expect(sportCallCount, 2, reason: '401 sonrasi tam bir retry yapilmali');
      expect(tokenCallCount, 1, reason: 'token bir kez yenilenmeli');
      expect(seenAuthHeaders[0], 'Bearer stale-token');
      expect(seenAuthHeaders[1], 'Bearer fresh-token',
          reason: 'BUG1: retry klonu eski token header\'ini tasimali');
    });

    test('auth/token 401 donerse sonsuz dongu OLMAZ (en fazla 2 istek)', () async {
      var totalCalls = 0;
      final mock = MockClient((request) async {
        totalCalls++;
        if (request.url.path.endsWith('/auth/token')) {
          // Gecersiz provisioning key -> 401
          return http.Response('invalid key', 401);
        }
        if (request.url.path.endsWith('/sport')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('not found', 404);
      });
      api.setTestClient(mock);

      await api.init();

      // init, stored token varsa true donebilir; asil iddia dongu OLMAMASI.
      expect(totalCalls, 1,
          reason: 'BUG2: auth 401 -> refresh -> auth 401 sonsuz dongusu '
              '(yalnizca 1 token istegi yapilmali, retry edilmemeli)');
    });

    test('401 olmayan hatalarda retry yapilmaz', () async {
      var sportCallCount = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/sport')) {
          sportCallCount++;
          return http.Response('server error', 500);
        }
        return http.Response('not found', 404);
      });
      api.setTestClient(mock);

      final result = await api.getSportPlans();

      expect(sportCallCount, 1, reason: '500 retry tetiklememeli');
      expect(result, isEmpty);
    });
  });

  group('groupFailed izolasyonu (bug: paylasilan flag paralel calismalarda eziliyordu)', () {
    late ApiClient api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = ApiClient();
      api.resetForTest();
    });

    test('medications hatasi sport/habits grubunu etkilemez', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/medications')) {
          return http.Response('error', 500);
        }
        if (request.url.path.endsWith('/sport')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('not found', 404);
      });
      api.setTestClient(mock);

      // Paralel cagri (HomeScreen'in gercekte yaptigi sey)
      await Future.wait([api.getMedications(), api.getSportPlans()]);

      expect(api.groupFailed('medications'), isTrue);
      expect(api.groupFailed('sport'), isFalse,
          reason: 'BUG3: baska grubun hatasi bu grubu ezmemeli');
    });

    test('basarili cagri grubun onceki hata durumunu temizler', () async {
      final failing = MockClient(
          (_) async => http.Response('error', 500));
      api.setTestClient(failing);
      await api.getHabits();
      expect(api.groupFailed('habits'), isTrue);

      final ok = MockClient(
          (_) async => http.Response(jsonEncode([]), 200));
      api.setTestClient(ok);
      await api.getHabits();
      expect(api.groupFailed('habits'), isFalse);
    });
  });

  group('NotificationIds bantlari (bug: med bandi ile step ID cakisiyordu)', () {
    test('modul bantlari cakismaz - tum id uzayinda benzersizlik', () {
      final all = <int>{};
      // Gercekte gorulebilir id araliklarini tara (0-10k plan, 1-7 gun)
      for (var id = 0; id <= 10000; id++) {
        for (var day = 1; day <= 7; day++) {
          all.add(NotificationIds.habit(id, day));
          all.add(NotificationIds.sport(id, day));
          all.add(NotificationIds.supplement(id, day));
        }
        all.add(NotificationIds.medication(id));
      }
      all.add(NotificationIds.step);

      // Ayni sayi -> hic cakisma yok
      final expectedCount = 3 * 10001 * 7 + 10001 + 1;
      expect(all.length, expectedCount,
          reason: 'BUG4: bantlar arasi ID cakismasi olmali mi');
    });

    test('tum ID\'ler Android 32-bit siniri icinde', () {
      expect(NotificationIds.step, lessThan(2147483648));
      // 100k plan id ile bile bantlar 32-bit icinde kalir
      expect(NotificationIds.habit(100000, 7), lessThan(2147483648));
      expect(NotificationIds.supplement(100000, 7), lessThan(2147483648));
    });

    test('med bandi habit bandina tasmiyor', () {
      expect(NotificationIds.medication(0), lessThan(2000000));
      expect(NotificationIds.medication(999999), lessThan(2000000));
    });
  });
}
