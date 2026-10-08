class ApiConfig {
  // Override at build/run time, e.g. if you'd rather use your PC's LAN IP
  // than adb reverse:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // NOTE on Android:
    //   - Android EMULATOR: use --dart-define=API_BASE_URL=http://10.0.2.2:4000
    //   - Real Android DEVICE over USB: run once per USB connection
    //         adb reverse tcp:4000 tcp:4000
    //     which forwards "localhost" on the phone back to your PC, so plain
    //     localhost below just works. (The app only talks to the backend on
    //     :4000 — the AI service on :5001 is called server-side.)
    return 'http://localhost:4000';
  }

  /// Full URL for a file stored under the backend's /uploads static route,
  /// e.g. mediaUrl('169...jpg') -> http://localhost:4000/uploads/169...jpg.
  /// Absolute URLs are returned unchanged.
  static String mediaUrl(String filename) {
    if (filename.isEmpty) return '';
    if (filename.startsWith('http://') || filename.startsWith('https://')) return filename;
    return '$baseUrl/uploads/$filename';
  }
}
