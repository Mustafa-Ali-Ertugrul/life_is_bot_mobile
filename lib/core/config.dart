// lib/core/config.dart
class AppConfig {
  // --dart-define=API_BASE_URL=... ile ezilebilir
  // Varsayılan: Android Emulator → host localhost (10.0.2.2)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  // Development API Key (backend .env'deki API_KEY_FALLBACK)
  static const String apiKey = 'test-key-12345';

  static const int timeoutSeconds = 10;
}
