import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color femaleColor = Color(0xFF4CAF50);
  static const Color maleColor = Color(0xFF00BCD4);

  static Color of(String gender) =>
      gender == 'female' ? femaleColor : maleColor;

  static Future<String> loadGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_gender') ?? 'male';
  }

  static Future<Color> loadColor() async => of(await loadGender());
}
