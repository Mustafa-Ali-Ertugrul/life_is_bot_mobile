import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirim servisini başlat
  await NotificationService.init();

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

  runApp(MyApp(home: home));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Is Bot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}
