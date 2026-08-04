import 'package:flutter_test/flutter_test.dart';

import 'package:life_is_bot/models/habit.dart';
import 'package:life_is_bot/models/medication.dart';

void main() {
  group('Medication backend contract', () {
    test('fromJson maps backend response fields', () {
      final medication = Medication.fromJson({
        'id': 7,
        'name': 'Aspirin',
        'dose': '100mg',
        'target_hour': 8,
        'target_minute': 5,
        'days_of_week': '1,2,3,4,5,6,7',
        'is_active': true,
      });

      expect(medication.id, 7);
      expect(medication.name, 'Aspirin');
      expect(medication.dosage, '100mg');
      expect(medication.reminderTime, '08:05');
      expect(medication.enabled, true);
    });

    test('toJson produces backend MedicationCreate payload', () {
      final medication = Medication(
        id: 0,
        name: 'Aspirin',
        dosage: '100mg',
        reminderTime: '08:00',
      );

      expect(medication.toJson(), {
        'name': 'Aspirin',
        'dose': '100mg',
        'target_hour': 8,
        'target_minute': 0,
        'days_of_week': '1,2,3,4,5,6,7',
      });
    });
  });

  group('Habit backend contract', () {
    test('fromJson maps backend response fields', () {
      final habit = Habit.fromJson({
        'id': 3,
        'name': 'Meditasyon',
        'target_hour': 7,
        'target_minute': 0,
        'days_of_week': '1,3,5',
        'is_active': true,
      });

      expect(habit.id, 3);
      expect(habit.name, 'Meditasyon');
      expect(habit.reminderTime, '07:00');
      expect(habit.days, [1, 3, 5]);
      expect(habit.enabled, true);
    });

    test('toJson produces backend HabitCreate payload', () {
      final habit = Habit(
        id: 0,
        name: 'Meditasyon',
        reminderTime: '07:00',
        days: [1, 3, 5],
      );

      expect(habit.toJson(), {
        'name': 'Meditasyon',
        'target_hour': 7,
        'target_minute': 0,
        'days_of_week': '1,3,5',
      });
    });
  });
}
