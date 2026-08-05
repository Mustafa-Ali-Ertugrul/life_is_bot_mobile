import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'core/app_navigator.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirim servisini başlat
  await NotificationService.init();

  // Foreground service — MIUI'da alarm teslimatı için process canlı tutulur
  await ForegroundService.init();

  // Bildirim izni iste
  await NotificationService.requestPermission();

  // Adım hatırlatmasını zamanla (tercihe bağlı)
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('step_reminders') ?? true) {
    await NotificationService.scheduleStepReminder();
  }

  // İlk açılışta 20 soruluk değerlendirme testi
  Widget home = const HomeScreen();
  if (!(prefs.getBool('onboarding_done') ?? false)) {
    final api = ApiClient();
    if (await api.checkHealth()) {
      home = const OnboardingScreen();
    }
  }

  // Tema: onboarding'de seçilen cinsiyete göre (varsayılan erkek)
  final female = (prefs.getString('user_gender') ?? 'male') == 'female';

  runApp(MyApp(home: home, female: female));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.home, this.female = false});

  final Widget home;
  final bool female;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Is Bot',
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: female ? AppTheme.femaleColor : AppTheme.maleColor,
        ),
        useMaterial3: true,
      ),
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}
