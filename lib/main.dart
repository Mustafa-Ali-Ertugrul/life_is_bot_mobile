import 'dart:async';

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

  // Bildirim servisini başlat (yerel işlemler; timezone + kanallar, hızlı)
  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();

  // Tema: onboarding'de seçilen cinsiyete göre (varsayılan erkek)
  final female = (prefs.getString('user_gender') ?? 'male') == 'female';
  final themeModeStr = prefs.getString('theme_mode') ?? 'system';
  ThemeMode themeMode = ThemeMode.system;
  if (themeModeStr == 'light') themeMode = ThemeMode.light;
  if (themeModeStr == 'dark') themeMode = ThemeMode.dark;

  // UI ilk frame'de gösterilir; ağa/izne bağlı işler arka planda yapılır.
  // Aksi halde backend yavaşsa en kötü ~20 sn beyaz ekran olurdu.
  Widget home = const HomeScreen();
  final api = ApiClient();
  if (!(prefs.getBool('onboarding_done') ?? false)) {
    // Yalnızca ilk açılışta backend kontrol edilir (≤10 sn);
    // sonraki açılışlar ağ beklemeden UI gösterir.
    await api.init();
    if (await api.checkHealth()) {
      home = const OnboardingScreen();
    }
  } else {
    // Token yoksa _AuthRetryClient ilk 401'de kendisi çeker.
    unawaited(api.init());
  }

  runApp(MyApp(home: home, female: female, initialThemeMode: themeMode));

  // Arka plan başlatma — MIUI'da alarm teslimatı için process canlı tutulur
  unawaited(ForegroundService.init());
  unawaited(_postLaunchInit());
}

Future<void> _postLaunchInit() async {
  // Bildirim izni iste (idempotent: verilmişse diyalog açmaz)
  await NotificationService.requestPermission();

  // Adım hatırlatmasını zamanla (tercihe bağlı, kullanıcı saati)
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('step_reminders') ?? true) {
    await NotificationService.scheduleStepReminder();
  }

  // --dart-define=TEST_BOT_NOTIFICATIONS=true ile her bot için test bildirimi
  const testBots = bool.fromEnvironment('TEST_BOT_NOTIFICATIONS');
  if (testBots) {
    await NotificationService.showTestBotNotifications();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.home, this.female = false, this.initialThemeMode = ThemeMode.system});

  final Widget home;
  final bool female;
  final ThemeMode initialThemeMode;

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setThemeMode(mode);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = widget.female ? AppTheme.femaleColor : AppTheme.maleColor;
    return MaterialApp(
      title: 'Life Is Bot',
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: widget.home,
      debugShowCheckedModeBanner: false,
    );
  }
}
