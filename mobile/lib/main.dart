import 'package:flutter/material.dart';

import 'app.dart';
import 'core/nav.dart';
import 'core/realtime.dart';
import 'core/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SiteNav.init();
  await Future.wait([Session.instance.load(), Settings.instance.load()]);
  final session = Session.instance;
  if (session.loggedIn) {
    Realtime.instance.connect(session.token!);
    Badges.instance.start();
    session.refresh(); // pick up wallet, profile and verification changes
  }
  runApp(const SureFixApp());
}
