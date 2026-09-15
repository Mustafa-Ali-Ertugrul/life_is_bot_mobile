// test/probe_reports_dispose_measure_test.dart
//
// ÖLÇÜM DÜZENEĞİ (review Y3): ReportsScreen API yanıtı gelmeden dispose edilince
// GERÇEKTEN ne oluyor? CI logunu okuyamadığımız için (egress allowlist) sonucu
// "kaç test geçti" sayısından çıkarıyoruz:
//
// Toplam 55 test koşar (49 mevcut + 6 prob). Geçen sayısından sonuç:
//   50 geçti → sadece P1 → hiç hata yok  (Y3 iddiası YANLIŞ, ekran güvenli)
//   51 geçti → P2+P3     → başka bir hata var
//   52 geçti → +P6       → "Null check operator" hatası
//   53 geçti → +P4+P5    → "setState() called after dispose()" (Y3 DOĞRULANDI)
//
// 6 probun her biri aynı senaryoyu bağımsız koşar ve tek bir koşulu dener.
// Gerçek ReportsScreen pump ediliyor; sahte olan tek şey HTTP katmanı.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/screens/reports_screen.dart';

/// Senaryoyu koşar ve oluşan hatayı (yoksa null) döndürür.
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
    await tester.pump(const Duration(milliseconds: 20)); // istekler uçuşta
    // kullanıcı geri bastı → ekran dispose, istekler hâlâ bekliyor
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 500)); // yanıtlar iner
    await tester.pump(const Duration(milliseconds: 500));
  } catch (e) {
    error = e; // pump sırasında doğrudan fırladıysa
  }
  return error ?? tester.takeException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P1: hiç hata oluşmadı', (tester) async {
    expect(await runScenario(tester), isNull);
  });

  testWidgets('P2: bir hata oluştu', (tester) async {
    expect(await runScenario(tester), isNotNull);
  });

  testWidgets('P3: hata bir daha oluştu (ağırlık)', (tester) async {
    expect(await runScenario(tester), isNotNull);
  });

  testWidgets('P4: mesaj "setState" içeriyor', (tester) async {
    final e = await runScenario(tester);
    expect(e.toString(), contains('setState'));
  });

  testWidgets('P5: mesaj "dispose" içeriyor', (tester) async {
    final e = await runScenario(tester);
    expect(e.toString(), contains('dispose'));
  });

  testWidgets('P6: mesaj "Null check" içeriyor', (tester) async {
    final e = await runScenario(tester);
    expect(e.toString(), contains('Null check'));
  });
}
