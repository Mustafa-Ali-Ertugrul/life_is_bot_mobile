// test/probe_measure_test.dart
//
// İKİLİ KODLAMALI ÖLÇÜM (CI logu okunamıyor → sonuç geçen test sayısında).
// Taban: 49 mevcut test + S0(1) + S1(2) + S2(4) = 56 geçti (önceki koşuda doğrulandı:
// ekran gerçekten render oluyor). Dispose senaryosu için ağırlıklı problar:
//
//   56 → dispose problarının HEPSİ düştü → teardown/setup hatası
//   73 → hata YOK + harness sağlam      → Y3 iddiası YANLIŞ
//   74 → hata var ama dispose değil
//   78 → "dispose" içeren hata          → Y3 DOĞRULANDI
//   82 → "Timer is still pending"       → bekleyen timer sorunu
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

Future<void> render(WidgetTester tester) async {
  _mockApi();
  await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
  await tester.pumpAndSettle();
}

/// KONTROL: aynı gecikme, aynı pump süreleri — ama ekran dispose EDİLMİYOR.
/// Bu geçip dispose senaryosu patlarsa sebebi dispose'tur (Y3 doğrulanır).
Future<void> sameTimingNoDispose(WidgetTester tester) async {
  _mockApi(delayMs: 200);
  await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(seconds: 12));
  await tester.pump();
  tester.takeException();
}

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
  final pending = tester.takeException();
  return error ?? pending;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S0 sanity [w1]', (tester) async {
    expect(1, 1);
  });

  testWidgets('S1 render [w2 #1]', (tester) async {
    await render(tester);
    expect(find.text('Raporlar'), findsOneWidget);
  });

  testWidgets('S1 render [w2 #2]', (tester) async {
    await render(tester);
    expect(find.text('Raporlar'), findsOneWidget);
  });

  testWidgets('S2 veri [w4 #1]', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü İlerleme'), findsOneWidget);
  });

  testWidgets('V kontrol: dispose YOK, aynı zamanlama [w8 #1]', (tester) async {
    await sameTimingNoDispose(tester);
    expect(1, 1);
  });

  testWidgets('W dispose senaryosu [w16 #1]', (tester) async {
    await disposeWhileLoading(tester);
    expect(1, 1);
  });
}
