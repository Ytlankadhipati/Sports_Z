import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend URL configuration.
///
/// Priority order:
///   1. --dart-define=API_BASE_URL=http://...  (highest priority — WiFi, CI, prod)
///   2. --dart-define=ADB_REVERSE=true         (USB cable + `adb reverse tcp:8000 tcp:8000`)
///   3. Platform default (web=127.0.0.1, android emulator=10.0.2.2, iOS=127.0.0.1)
///
/// USB cable se physical device connect hai toh:
///   adb reverse tcp:8000 tcp:8000
///   flutter run --dart-define=ADB_REVERSE=true
///
/// WiFi pe physical device connect hai toh:
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
class ApiConfig {
  static const int port = 8000;

  static String get baseUrl {
    // 1. Explicit URL override (WiFi / production)
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    // 2. ADB reverse mode: physical device via USB cable
    //    Run: adb reverse tcp:8000 tcp:8000
    //    Then: flutter run --dart-define=ADB_REVERSE=true
    const adbReverse = bool.fromEnvironment('ADB_REVERSE');
    if (adbReverse) return 'http://127.0.0.1:$port';

    // 3. Platform defaults
    if (kIsWeb) return 'http://127.0.0.1:$port';

    // Android Emulator: 10.0.2.2 = host machine's localhost
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port';
    }

    // iOS Simulator / macOS / other
    return 'http://127.0.0.1:$port';
  }
}
