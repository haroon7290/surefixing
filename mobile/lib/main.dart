import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/realtime_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/technician/tech_home.dart';
import 'screens/supplier/supplier_home.dart';
import 'screens/admin/admin_home.dart';

// Global key so realtime events (which arrive outside the widget tree's
// BuildContext) can show snackbars on whatever screen is currently visible.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.load();
  if (AuthService.instance.token != null) {
    RealtimeService.instance.connect(AuthService.instance.token!);
  }
  RealtimeService.instance.events.listen(_onRealtime);
  runApp(const FixItApp());
}

void _onRealtime(RealtimeEvent e) {
  // Toast for any DB-backed notification. Type-specific events (job:new,
  // tool:rented, message:new, etc.) are consumed by the screens that care
  // about them — they're for live data refresh, not for toasts.
  if (e.name == 'notification') {
    final title = (e.data['title'] ?? '').toString();
    final body = (e.data['body'] ?? '').toString();
    final msg = body.isEmpty ? title : '$title — $body';
    if (msg.isNotEmpty) _toast(msg);
  } else if (e.name == 'job:new') {
    // Fanned out to every connected technician — there's no DB notification
    // for it (would spam everyone's inbox), so toast it directly.
    final title = (e.data['title'] ?? '').toString();
    if (title.isNotEmpty) _toast('New job posted: $title');
  }
}

void _toast(String message) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ));
}

class FixItApp extends StatelessWidget {
  const FixItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixIt',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const RootRouter(),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    if (!auth.loggedIn) return const LoginScreen();
    return homeForRole(auth.user!.role);
  }
}

Widget homeForRole(String role) {
  switch (role) {
    case 'client':
      return const ClientHome();
    case 'technician':
      return const TechHome();
    case 'supplier':
      return const SupplierHome();
    case 'admin':
      return const AdminHome();
    default:
      return const LoginScreen();
  }
}
