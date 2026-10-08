import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override at build/run time, e.g. if you'd rather use your PC's LAN IP
  // than adb reverse:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // NOTE on Android:
    //   - Android EMULATOR: 10.0.2.2 is the special alias for the host PC.
    //   - Real Android DEVICE over USB: 10.0.2.2 does NOT work. Instead run
    //     once per USB connection:
    //         adb reverse tcp:4000 tcp:4000
    //         adb reverse tcp:5001 tcp:5001
    //     which forwards "localhost" on the phone back to your PC, so plain
    //     localhost below just works. (The app only talks to the backend on
    //     :4000 directly -- the AI service on :5001 is called server-side by
    //     the backend, so that reverse is optional, but harmless to run.)
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://localhost:4000';
  }

  /// Builds a full URL for a file stored under the backend's /uploads
  /// static route, e.g. mediaUrl('169...jpg') -> http://localhost:4000/uploads/169...jpg
  static String mediaUrl(String filename) {
    if (filename.isEmpty) return '';
    return '$baseUrl/uploads/$filename';
  }
}