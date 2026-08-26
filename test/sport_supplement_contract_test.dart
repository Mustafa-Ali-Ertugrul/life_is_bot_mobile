import 'package:flutter_test/flutter_test.dart';
import 'package:life_is_bot/models/sport_plan.dart';
import 'package:life_is_bot/models/supplement_plan.dart';

void main() {
  group('SportPlan backend contract', () {
    test('fromJson maps backend response fields', () {
      final plan = SportPlan.fromJson({
        'id': 12,
        'sport_type': 'Koşu',
        'target_hour': 18,
        'target_minute': 30,
        'days_of_week': '1,3,5',
        'is_active': true,
      });
      expect(plan.id, 12);
      expect(plan.sportType, 'Koşu');
      expect(plan.targetHour, 18);
      expect(plan.targetMinute, 30);
      expect(plan.daysOfWeek, '1,3,5');
      expect(plan.isActive, true);
      expect(plan.timeText, '18:30');
      expect(plan.daysText, 'Pzt, Çar, Cum');
    });

    test('fromJson uses defaults when fields missing', () {
      final plan = SportPlan.fromJson({'id': 1});
      expect(plan.sportType, '');
      expect(plan.targetHour, 0);
      expect(plan.targetMinute, 0);
      expect(plan.daysOfWeek, '1,2,3,4,5,6,7');
      expect(plan.isActive, true);
      expect(plan.daysText, 'Her gün');
    });

    test('toJson produces backend SportCreate payload', () {
      final plan = SportPlan(
        id: 0,
        sportType: 'Yoga',
        targetHour: 7,
        targetMinute: 5,
        daysOfWeek: '1,2,3',
      );
      expect(plan.toJson(), {
        'sport_type': 'Yoga',
        'target_hour': 7,
        'target_minute': 5,
        'days_of_week': '1,2,3',
        'is_active': true,
      });
    });

    test('timeText pads hour and minute', () {
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 7, targetMinute: 5).timeText, '07:05');
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 18, targetMinute: 0).timeText, '18:00');
    });

    test('daysText handles full week and partial', () {
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '1,2,3,4,5,6,7').daysText, 'Her gün');
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '1').daysText, 'Pzt');
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '6,7').daysText, 'Cmt, Paz');
      expect(SportPlan(id: 1, sportType: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '').daysText, 'Her gün');
    });

    test('is_active false maps correctly', () {
      final plan = SportPlan.fromJson({
        'id': 3,
        'sport_type': 'Ağırlık',
        'target_hour': 19,
        'target_minute': 0,
        'days_of_week': '2,4',
        'is_active': false,
      });
      expect(plan.isActive, false);
    });
  });

  group('SupplementPlan backend contract', () {
    test('fromJson maps backend response fields', () {
      final supp = SupplementPlan.fromJson({
        'id': 5,
        'name': 'Whey Protein',
        'dose': '30g',
        'target_hour': 9,
        'target_minute': 15,
        'days_of_week': '1,2,3,4,5,6,7',
        'is_active': true,
      });
      expect(supp.id, 5);
      expect(supp.name, 'Whey Protein');
      expect(supp.dose, '30g');
      expect(supp.targetHour, 9);
      expect(supp.targetMinute, 15);
      expect(supp.daysOfWeek, '1,2,3,4,5,6,7');
      expect(supp.enabled, true);
      expect(supp.timeText, '09:15');
      expect(supp.daysText, 'Her Gün');
    });

    test('fromJson handles missing dose and defaults', () {
      final supp = SupplementPlan.fromJson({
        'id': 2,
        'name': 'Omega-3',
        'target_hour': 20,
        'target_minute': 0,
      });
      expect(supp.dose, isNull);
      expect(supp.targetHour, 20);
      expect(supp.daysOfWeek, '1,2,3,4,5,6,7');
      expect(supp.enabled, true);
    });

    test('toJson produces backend SupplementCreate payload', () {
      final supp = SupplementPlan(
        id: 0,
        name: 'Kreatin',
        dose: '5g',
        targetHour: 8,
        targetMinute: 0,
        daysOfWeek: '1,3,5',
      );
      expect(supp.toJson(), {
        'name': 'Kreatin',
        'dose': '5g',
        'target_hour': 8,
        'target_minute': 0,
        'days_of_week': '1,3,5',
      });
    });

    test('toJson keeps null dose when not set', () {
      final supp = SupplementPlan(
        id: 0,
        name: 'Vitamin D',
        targetHour: 10,
        targetMinute: 30,
        daysOfWeek: '1,2,3,4,5,6,7',
      );
      final json = supp.toJson();
      expect(json['dose'], isNull);
      expect(json['name'], 'Vitamin D');
    });

    test('timeText pads correctly', () {
      expect(SupplementPlan(id: 1, name: 'X', targetHour: 7, targetMinute: 5, daysOfWeek: '1').timeText, '07:05');
    });

    test('daysText handles partial and full week', () {
      expect(SupplementPlan(id: 1, name: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '1,2,3,4,5,6,7').daysText, 'Her Gün');
      expect(SupplementPlan(id: 1, name: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '2,4').daysText, 'Sal, Per');
      expect(SupplementPlan(id: 1, name: 'X', targetHour: 8, targetMinute: 0, daysOfWeek: '7').daysText, 'Paz');
    });

    test('is_active false maps to enabled false', () {
      final supp = SupplementPlan.fromJson({
        'id': 8,
        'name': 'Test',
        'target_hour': 12,
        'target_minute': 0,
        'days_of_week': '1',
        'is_active': false,
      });
      expect(supp.enabled, false);
    });
  });

  group('ApiClient payload shape regression', () {
    test('SportPlan and SupplementPlan share days_of_week string format', () {
      final sport = SportPlan(id: 0, sportType: 'Koşu', targetHour: 18, targetMinute: 0, daysOfWeek: '1,3,5');
      final supp = SupplementPlan(id: 0, name: 'Protein', dose: '1 ölçek', targetHour: 9, targetMinute: 0, daysOfWeek: '1,3,5');
      expect(sport.toJson()['days_of_week'], '1,3,5');
      expect(supp.toJson()['days_of_week'], '1,3,5');
    });

    test('backend create endpoints expect target_hour/minute as int', () {
      final sportJson = SportPlan(id: 0, sportType: 'Pilates', targetHour: 7, targetMinute: 30, daysOfWeek: '2,4').toJson();
      expect(sportJson['target_hour'], isA<int>());
      expect(sportJson['target_minute'], isA<int>());
      final suppJson = SupplementPlan(id: 0, name: 'Mg', dose: '400mg', targetHour: 22, targetMinute: 15, daysOfWeek: '1,2,3').toJson();
      expect(suppJson['target_hour'], isA<int>());
      expect(suppJson['target_minute'], isA<int>());
    });
  });
}
