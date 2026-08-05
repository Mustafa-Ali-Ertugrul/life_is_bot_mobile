import 'package:flutter/material.dart';
import '../screens/habits_screen.dart';
import '../screens/medications_screen.dart';
import '../screens/steps_screen.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static void openForPayload(String? payload) {
    final state = key.currentState;
    if (state == null || payload == null || payload.isEmpty) return;

    if (payload.startsWith('medication_')) {
      state.push(MaterialPageRoute(builder: (_) => const MedicationsScreen()));
    } else if (payload.startsWith('habit_')) {
      state.push(MaterialPageRoute(builder: (_) => const HabitsScreen()));
    } else if (payload.startsWith('steps_')) {
      state.push(MaterialPageRoute(builder: (_) => const StepsScreen()));
    }
  }
}
