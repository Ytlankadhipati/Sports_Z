import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const int port = 8000;

  static String get baseUrl {
    // Real phone ke liye: flutter run --dart-define=API_BASE_URL=http://<PC-IP>:8000
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    // Chrome / Web
    if (kIsWeb) return 'http://127.0.0.1:$port';

    // Android Emulator (10.0.2.2 = PC ka localhost)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port';
    }

    // iOS simulator / baaki
    return 'http://127.0.0.1:$port';
  }
}