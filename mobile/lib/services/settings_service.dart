import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences: theme mode and whether onboarding was seen.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  ThemeMode themeMode = ThemeMode.system;
  bool onboardingSeen = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString('themeMode'),
      orElse: () => ThemeMode.system,
    );
    onboardingSeen = prefs.getBool('onboardingSeen') ?? false;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> completeOnboarding() async {
    onboardingSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingSeen', true);
  }
}
