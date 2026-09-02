import 'package:flutter_test/flutter_test.dart';
import 'package:life_is_bot/core/app_navigator.dart';

void main() {
  group('AppNavigator.parsePayload', () {
    test('medication payload → ekran + id', () {
      expect(AppNavigator.parsePayload('medication_5'), ('medication', 5));
    });

    test('habit payload → ekran + id', () {
      expect(AppNavigator.parsePayload('habit_12'), ('habit', 12));
    });

    test('sport payload → ekran + id', () {
      expect(AppNavigator.parsePayload('sport_3'), ('sport', 3));
    });

    test('supplement payload → ekran + id', () {
      expect(AppNavigator.parsePayload('supplement_9'), ('supplement', 9));
    });

    test('steps hatırlatıcısı id taşımaz', () {
      expect(AppNavigator.parsePayload('steps_reminder'), ('steps', null));
    });

    test('sayısal olmayan id ekranı korur, id düşer', () {
      expect(AppNavigator.parsePayload('medication_abc'), ('medication', null));
    });

    test('bilinmeyen payload → boş ekran', () {
      expect(AppNavigator.parsePayload('unknown_1'), ('', null));
    });

    test('boş payload → boş ekran', () {
      expect(AppNavigator.parsePayload(''), ('', null));
    });
  });
}
