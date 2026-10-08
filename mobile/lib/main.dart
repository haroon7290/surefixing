import 'package:flutter/material.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/badge_service.dart';
import 'services/realtime_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([AuthService.instance.load(), SettingsService.instance.load()]);
  final auth = AuthService.instance;
  if (auth.loggedIn) {
    RealtimeService.instance.connect(auth.token!);
    BadgeService.instance.start();
    auth.refreshUser(); // pick up profile/KYC changes made while offline
  }
  runApp(const SureFixApp());
}
