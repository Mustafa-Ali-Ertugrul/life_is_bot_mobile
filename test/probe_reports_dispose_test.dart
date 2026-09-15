// test/probe_reports_dispose_test.dart
//
// PROB (review Y3): ReportsScreen API yanıtı gelmeden ekrandan çıkılınca
// "setState() called after dispose()" hatası veriyor mu?
//
// Bu bir birim test DEĞİL: gerçek ReportsScreen widget'ı gerçek Flutter
// framework'ünde pump ediliyor, layout/build gerçekten çalışıyor. Sahte olan
// tek şey HTTP katmanı (gecikmeli MockClient) ve SharedPreferences.
//
// Test YEŞİL ise: dispose sonrası setState gerçekten patlıyor (bug doğrulandı).
// Test KIRMIZI ise: iddia yanlış, ekran güvenli.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_is_bot/core/api_client.dart';
import 'package:life_is_bot/screens/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ReportsScreen: yükleme sürerken pop edilirse setState-after-dispose fırlar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'user_gender': 'male'});

      final api = ApiClient()
        ..resetForTest()
        ..setTestToken('probe-token');

      // Ağ gecikmeli: bu pencerede ekran dispose edilecek.
      api.setTestClient(MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(
          jsonEncode({
            'total': 5,
            'completed': 3,
            'missed': 1,
            'unanswered': 1,
            'current': 12,
          }),
          200,
        );
      }));

      await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));
      // initState → _loadReports() başladı, 4 paralel istek uçuşta
      await tester.pump(const Duration(milliseconds: 50));

      // Kullanıcı geri bastı: ekran dispose ediliyor, istekler hâlâ bekliyor
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Yanıtlar şimdi iner ve dispose edilmiş State üzerinde setState çağrılır
      await tester.pump(const Duration(milliseconds: 600));

      final error = tester.takeException();
      expect(error, isNotNull,
          reason: 'Y3: dispose sonrası setState hatası bekleniyordu');
      expect(error.toString(), contains('setState() called after dispose()'),
          reason: 'Y3: hata mesajı dispose-sonrası setState olmalı');
    },
  );
}
