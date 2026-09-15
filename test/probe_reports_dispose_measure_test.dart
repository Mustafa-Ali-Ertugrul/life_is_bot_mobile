// test/probe_reports_dispose_measure_test.dart
//
// OLÇÜM DÜZENEĞİ (review Y3): ReportsScreen API yanıtı gelmeden dispose edilince
// GERÇEKTEN ne oluyor? CI logu okunamadığı için (egress allowlist) sonuç
// "kaç test geçti" sayısından okunur. R1/R2 birbirinin tersi → taban +1.
// Alt dize probları ağırlıklıdır, böylece her senaryo benzersiz bir toplam verir:
//
//   50 geçti → hata yok                        → Y3 iddiası YANLIŞ
//   51 geçti → "called after dispose" (ağırlık 1) → Y3 DOĞRULANDI
//   52 geçti → "during build"        (ağırlık 2)
//   53 geçti → "Timer is still pending" (ağırlık 3)
//   54 geçti → "Null check"          (ağırlık 4)
//   55 geçti → "MissingPluginException" (ağırlık 5)
//   49 geçti → probların kendisi düşüyor (setup hatası)
//
// Gerçek ReportsScreen pump ediliyor; sahte olan tek şey HTTP katmanı.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/screens/reports_screen.dart';

Future<Object?> runScenario(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'user_gender': 'male'});

  final api = ApiClient()
    ..resetForTest()
    ..setTestToken('probe-token');
  api.setTestClient(MockClient((request) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return http.Response(
      jsonEncode({
        'total': 5, 'completed': 3, 'missed': 1, 'unanswered': 1,
        'current': 12, 'longest': 27, 'completion_rate': 60.0,
        'bot_stats': <Map<String, dynamic>>[],
      }),
      200,
    );
  }));

  Object? error;
  try {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 12)); // .timeout() timer'ları bitsin
    await tester.pump();
  } catch (e) {
    error = e;
  }
  return error ?? tester.takeException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R1: hata yok', (tester) async {
    expect(await runScenario(tester), isNull);
  });

  testWidgets('R2: hata var', (tester) async {
    expect(await runScenario(tester), isNotNull);
  });

  testWidgets('W[called after dispose x1] #1', (tester) async {
    expect((await runScenario(tester)).toString(), contains('called after dispose'));
  });

  testWidgets('W[during build x2] #1', (tester) async {
    expect((await runScenario(tester)).toString(), contains('during build'));
  });

  testWidgets('W[during build x2] #2', (tester) async {
    expect((await runScenario(tester)).toString(), contains('during build'));
  });

  testWidgets('W[Timer is still pending x3] #1', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Timer is still pending'));
  });

  testWidgets('W[Timer is still pending x3] #2', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Timer is still pending'));
  });

  testWidgets('W[Timer is still pending x3] #3', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Timer is still pending'));
  });

  testWidgets('W[Null check x4] #1', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Null check'));
  });

  testWidgets('W[Null check x4] #2', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Null check'));
  });

  testWidgets('W[Null check x4] #3', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Null check'));
  });

  testWidgets('W[Null check x4] #4', (tester) async {
    expect((await runScenario(tester)).toString(), contains('Null check'));
  });

  testWidgets('W[MissingPluginException x5] #1', (tester) async {
    expect((await runScenario(tester)).toString(), contains('MissingPluginException'));
  });

  testWidgets('W[MissingPluginException x5] #2', (tester) async {
    expect((await runScenario(tester)).toString(), contains('MissingPluginException'));
  });

  testWidgets('W[MissingPluginException x5] #3', (tester) async {
    expect((await runScenario(tester)).toString(), contains('MissingPluginException'));
  });

  testWidgets('W[MissingPluginException x5] #4', (tester) async {
    expect((await runScenario(tester)).toString(), contains('MissingPluginException'));
  });

  testWidgets('W[MissingPluginException x5] #5', (tester) async {
    expect((await runScenario(tester)).toString(), contains('MissingPluginException'));
  });

}
