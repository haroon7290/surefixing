import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/auth/auth_screens.dart';
import 'features/chat/chat_screen.dart';
import 'features/shell/shell.dart';
import 'features/shell/web_frame.dart';
import 'features/site/public_site.dart';
import 'kit.dart';
import 'routes.dart';

class SureFixApp extends StatefulWidget {
  const SureFixApp({super.key});

  @override
  State<SureFixApp> createState() => _SureFixAppState();
}

class _SureFixAppState extends State<SureFixApp> with WidgetsBindingObserver {
  StreamSubscription<RealtimeEvent>? _sub;
  bool _wasLoggedIn = Session.instance.loggedIn;

  @override
  void initState() {
    super.initState();
    _sub = Realtime.instance.events.listen(_onRealtime);
    Session.instance.addListener(_onSessionChanged);
    // Registered before MaterialApp's own observer, so address-bar changes
    // (…/#/tools) switch sections instead of pushing unknown named routes.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageForPath(SiteNav.initialRoute) == null) SiteNav.syncUrl();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    Session.instance.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The address bar changed (typed URL, browser forward).
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final route = routeInformation.uri.toString();
    final page = pageForPath(route);
    if (page != null) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page, settings: RouteSettings(name: routeInformation.uri.path)));
    } else {
      SiteNav.go(SiteNav.sectionOf(route));
    }
    return true;
  }

  void _onSessionChanged() {
    final now = Session.instance.loggedIn;
    if (now == _wasLoggedIn) return;
    _wasLoggedIn = now;
    // Back to the root gate (public site or the new user's home).
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    SiteNav.select('home');
    now ? Badges.instance.start() : Badges.instance.stop();
  }

  // Toasts for events that matter wherever the user is.
  void _onRealtime(RealtimeEvent e) {
    final me = Session.instance.user;
    final context = navigatorKey.currentContext;
    if (me == null || context == null) return;
    switch (e.name) {
      case 'notification':
        final title = str(e.data['title']);
        final body = str(e.data['body']);
        final data = asJson(e.data['data']);
        toast(
          body.isEmpty ? title : '$title — $body',
          actionLabel: data.isEmpty ? null : 'View',
          onAction: () => openTarget(navigatorKey.currentContext!, type: str(e.data['type']), data: data),
        );
      case 'job:new':
        if (!me.isTechnician) return;
        if (me.skills.isNotEmpty && !me.skills.contains(str(e.data['category']))) return;
        toast('New job: ${e.data['title']}', actionLabel: 'View', onAction: () => openJob(navigatorKey.currentContext!, e.jobId));
      case 'message:new':
        final sender = str(e.data['sender']);
        if (sender == me.id) return;
        final thread = str(e.data['thread']);
        if (ChatScreen.isOpen(thread, sender)) return;
        final isTool = thread.startsWith('tool:');
        final text = str(e.data['text']);
        final name = str(e.data['senderName'], 'New message');
        toast(
          '$name: ${text.isEmpty ? 'sent a photo' : text}',
          actionLabel: 'Reply',
          onAction: () => openChat(
            navigatorKey.currentContext!,
            ChatTarget(
              jobId: isTool ? '' : str(e.data['job']),
              toolId: isTool ? str(e.data['tool']) : '',
              otherId: sender,
              otherName: name,
              subject: str(e.data[isTool ? 'toolName' : 'jobTitle']),
            ),
          ),
        );
    }
  }

  List<Route<dynamic>> _initialRoutes(String route) {
    final page = pageForPath(route);
    return [
      // No name on the root: the navigator would report it as "/" and wipe
      // the section from the address bar (SiteNav keeps that in sync).
      MaterialPageRoute(builder: (_) => const RootGate()),
      if (page != null) MaterialPageRoute(builder: (_) => page, settings: RouteSettings(name: Uri.parse(route).path)),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Settings.instance,
        builder: (_, __) => MaterialApp(
          title: 'SureFix',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: Settings.instance.themeMode,
          navigatorObservers: [SectionUrlObserver()],
          onGenerateInitialRoutes: _initialRoutes,
          onGenerateRoute: (settings) {
            final page = pageForPath(settings.name ?? '/');
            return MaterialPageRoute(builder: (_) => page ?? const RootGate(), settings: page == null ? null : settings);
          },
          builder: (context, child) => WebFrame(child: child!),
        ),
      );
}

/// Chooses the first screen. Signed in: the role's app. Signed out: the
/// public website (in a browser or any wide window), or on a phone the
/// introduction followed by the sign-in screens.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Session.instance, Settings.instance, SiteNav.section]),
        builder: (context, _) {
          final session = Session.instance;
          if (session.loggedIn) return HomeShell(key: ValueKey('${session.user!.id}-${session.role}'), role: session.role);
          if (kIsWeb || context.isWide) return const PublicSite();
          if (!Settings.instance.introSeen) return const IntroScreen();
          return switch (SiteNav.section.value) {
            'register' => const _BackToLogin(child: RegisterScreen()),
            'forgot' => const _BackToLogin(child: ForgotPasswordScreen()),
            _ => const LoginScreen(),
          };
        },
      );
}

/// On phones the system back button returns from sign-up to log in.
class _BackToLogin extends StatelessWidget {
  final Widget child;
  const _BackToLogin({required this.child});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) SiteNav.select('login');
        },
        child: child,
      );
}
