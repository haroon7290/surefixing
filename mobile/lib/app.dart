import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/routes.dart';
import 'screens/shared/chat_screen.dart';
import 'screens/shells.dart';
import 'services/auth_service.dart';
import 'services/badge_service.dart';
import 'services/navigation.dart';
import 'services/realtime_service.dart';
import 'services/settings_service.dart';

class SureFixApp extends StatefulWidget {
  const SureFixApp({super.key});

  @override
  State<SureFixApp> createState() => _SureFixAppState();
}

class _SureFixAppState extends State<SureFixApp> {
  StreamSubscription<RealtimeEvent>? _sub;
  bool _wasLoggedIn = AuthService.instance.loggedIn;

  @override
  void initState() {
    super.initState();
    _sub = RealtimeService.instance.events.listen(_onRealtime);
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final now = AuthService.instance.loggedIn;
    if (now == _wasLoggedIn) return;
    _wasLoggedIn = now;
    // Back to the root gate (login or the new user's home) on any session change.
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    if (now) {
      BadgeService.instance.start();
    } else {
      BadgeService.instance.stop();
    }
  }

  // Global toasts for events that matter wherever the user is.
  void _onRealtime(RealtimeEvent e) {
    final me = AuthService.instance.user;
    if (me == null) return;
    final ctx = navigatorKey.currentContext;
    switch (e.name) {
      case 'notification':
        final title = (e.data['title'] ?? '').toString();
        final body = (e.data['body'] ?? '').toString();
        final data = e.data['data'] is Map ? Map<String, dynamic>.from(e.data['data']) : <String, dynamic>{};
        toast(
          body.isEmpty ? title : '$title — $body',
          action: ctx == null || data.isEmpty
              ? null
              : SnackBarAction(
                  label: 'View', onPressed: () => openTarget(navigatorKey.currentContext!, type: e.data['type']?.toString(), data: data)),
        );
      case 'job:new':
        if (!me.isTechnician) return;
        final cat = (e.data['category'] ?? '').toString();
        final matches = me.skills.isEmpty || me.skills.contains(cat);
        if (!matches) return;
        toast(
          'New job near you: ${e.data['title']}',
          action: SnackBarAction(
            label: 'View',
            onPressed: () => openTarget(navigatorKey.currentContext!, data: {'jobId': e.data['jobId']}),
          ),
        );
      case 'message:new':
        final sender = (e.data['sender'] ?? '').toString();
        if (sender == me.id) return;
        final jobId = (e.data['job'] ?? '').toString();
        if (ChatScreen.isOpen(jobId, sender)) return;
        final text = (e.data['text'] ?? '').toString();
        toast(
          '${e.data['senderName'] ?? 'New message'}: ${text.isEmpty ? '📷 Photo' : text}',
          action: SnackBarAction(
            label: 'Reply',
            onPressed: () => push(
              navigatorKey.currentContext!,
              ChatScreen(
                  jobId: jobId,
                  otherId: sender,
                  otherName: (e.data['senderName'] ?? '').toString(),
                  jobTitle: (e.data['jobTitle'] ?? '').toString()),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (_, __) => MaterialApp(
        title: 'SureFix',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,
        home: const RootGate(),
      ),
    );
  }
}

/// Chooses the first screen: onboarding → login → the role's home.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthService.instance, SettingsService.instance]),
      builder: (_, __) {
        final auth = AuthService.instance;
        if (!SettingsService.instance.onboardingSeen && !auth.loggedIn) return const OnboardingScreen();
        if (!auth.loggedIn) return const LoginScreen();
        return HomeShell(key: ValueKey('${auth.user!.id}-${auth.user!.role}'), role: auth.user!.role);
      },
    );
  }
}
