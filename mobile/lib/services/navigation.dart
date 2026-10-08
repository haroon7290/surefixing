import 'package:flutter/material.dart';

/// Global keys so code outside the widget tree (realtime events, the API
/// client's 401 handler) can navigate and show toasts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastKind { info, success, error }

void toast(String message, {ToastKind kind = ToastKind.info, SnackBarAction? action, Duration? duration}) {
  final messenger = messengerKey.currentState;
  if (messenger == null || message.isEmpty) return;
  final icon = switch (kind) {
    ToastKind.success => Icons.check_circle_rounded,
    ToastKind.error => Icons.error_rounded,
    ToastKind.info => Icons.notifications_active_rounded,
  };
  final color = switch (kind) {
    ToastKind.success => const Color(0xFF32D583),
    ToastKind.error => const Color(0xFFF97066),
    ToastKind.info => const Color(0xFF84ADFF),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      action: action,
      duration: duration ?? const Duration(seconds: 4),
    ));
}

void toastError(Object error) => toast(error.toString().replaceFirst('Exception: ', ''), kind: ToastKind.error);

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
