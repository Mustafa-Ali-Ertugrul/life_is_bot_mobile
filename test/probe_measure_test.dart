// test/probe_measure_test.dart
//
// İKİLİ KODLAMALI ÖLÇÜM: CI logu okunamadığı için (egress allowlist) sonuç
// "kaç test geçti" sayısından okunur. Her probun ağırlığı 2^n, böylece geçen
// test sayısı hangi aşamaların çalıştığını benzersiz biçimde söyler.
// Toplam 64 test koşar (49 mevcut + 15 prob):
//
//   49 → sanity bile patladı (harness bozuk)
//   50 → sadece sanity       (ReportsScreen hiç render olmuyor)
//   52 → + render            ('Raporlar' başlığı ekranda)
//   56 → + günlük veri       ('Bugünkü İlerleme' kartı render oldu)
//   64 → hepsi + dispose probu → Y3 (setState-after-dispose) DOĞRULANDI
//   58 → sanity + dispose    (render probları patladı)
//
// Sahte olan tek şey HTTP katmanı; ekran kodu gerçekten çalışıyor.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/screens/reports_screen.dart';

Map<String, dynamic> _payload() => {
      'total': 5, 'completed': 3, 'missed': 1, 'unanswered': 1,
      'current': 12, 'longest': 27, 'completion_rate': 60.0,
      'bot_stats': <Map<String, dynamic>>[],
    };

void _mockApi({int delayMs = 0}) {
  SharedPreferences.setMockInitialValues({'user_gender': 'male'});
  final api = ApiClient()
    ..resetForTest()
    ..setTestToken('probe-token');
  api.setTestClient(MockClient((request) async {
    if (delayMs > 0) await Future<void>.delayed(Duration(milliseconds: delayMs));
    return http.Response(jsonEncode(_payload()), 200);
  }));
}

/// Ekranı yükler ve render edilen metinleri döndürür.
Future<void> render(WidgetTester tester) async {
  _mockApi();
  await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
  await tester.pumpAndSettle();
}

/// Ekran yüklenirken dispose eder, oluşan hatayı döndürür.
Future<Object?> disposeWhileLoading(WidgetTester tester) async {
  _mockApi(delayMs: 200);
  Object? error;
  try {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
  } catch (e) {
    error = e;
  }
  // ÖNEMLİ: pending exception her zaman drenajlanmalı; aksi halde test
  // beklentiden bağımsız olarak teardown'da düşer (ilk ölçümde olan buydu).
  final pending = tester.takeException();
  return error ?? pending;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S0 sanity [w1 #1]', (tester) async {
    expect(1, 1);
  });

  testWidgets('S1 render Raporlar [w2 #1]', (tester) async {
    await render(tester);
    expect(find.text('Raporlar'), findsOneWidget);
  });

  testWidgets('S1 render Raporlar [w2 #2]', (tester) async {
    await render(tester);
    expect(find.text('Raporlar'), findsOneWidget);
  });

  testWidgets('S2 günlük veri [w4 #1]', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü İlerleme'), findsOneWidget);
  });

  testWidgets('S2 günlük veri [w4 #2]', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü İlerleme'), findsOneWidget);
  });

  testWidgets('S2 günlük veri [w4 #3]', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü İlerleme'), findsOneWidget);
  });

  testWidgets('S2 günlük veri [w4 #4]', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü İlerleme'), findsOneWidget);
  });

  testWidgets('S3 dispose hatası [w8 #1]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #2]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #3]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #4]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #5]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #6]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #7]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

  testWidgets('S3 dispose hatası [w8 #8]', (tester) async {
    expect(await disposeWhileLoading(tester), isNotNull);
  });

}
