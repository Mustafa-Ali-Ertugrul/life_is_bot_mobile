// lib/core/config.dart
class AppConfig {
  // Android Emulator → localhost için 10.0.2.2 kullan
  // Gerçek telefon için Cloudflare Tunnel URL'i kullan
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // Development API Key (backend .env'deki API_KEY_FALLBACK)
  static const String apiKey = 'test-key-12345';

  static const int timeoutSeconds = 10;
}
