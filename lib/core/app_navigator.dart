import 'package:flutter/material.dart';
import '../screens/habits_screen.dart';
import '../screens/medications_screen.dart';
import '../screens/sport_screen.dart';
import '../screens/steps_screen.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Bildirim payload'ını (ekran, öğe id'si) çiftine ayrıştırır.
  /// 'medication_5' → ('medication', 5); 'steps_reminder' → ('steps', null);
  /// 'medication_abc' → ('medication', null). Bilinmeyen → ('', null).
  static (String, int?) parsePayload(String payload) {
    const screens = ['medication', 'habit', 'sport', 'supplement', 'steps'];
    for (final screen in screens) {
      if (payload == screen || payload.startsWith('${screen}_')) {
        final rest = payload.substring(screen.length + 1);
        return (screen, int.tryParse(rest));
      }
    }
    return ('', null);
  }

  static void openForPayload(String? payload) {
    final state = key.currentState;
    if (state == null || payload == null || payload.isEmpty) return;

    final (screen, id) = parsePayload(payload);
    if (screen == 'medication') {
      state.push(
        MaterialPageRoute(builder: (_) => MedicationsScreen(focusId: id)),
      );
    } else if (screen == 'habit') {
      state.push(
        MaterialPageRoute(builder: (_) => HabitsScreen(focusId: id)),
      );
    } else if (screen == 'steps') {
      state.push(MaterialPageRoute(builder: (_) => const StepsScreen()));
    } else if (screen == 'sport' || screen == 'supplement') {
      state.push(
        MaterialPageRoute(builder: (_) => SportScreen(focusId: id)),
      );
    }
  }
}
