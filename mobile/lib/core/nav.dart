import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/icons.dart';
import 'format.dart';
import 'responsive.dart';
import 'theme.dart';

/// Global keys so code outside the widget tree (realtime events, the API
/// client's sign-out handler) can navigate and show toasts.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastKind { info, success, error }

void toast(String message, {ToastKind kind = ToastKind.info, String? actionLabel, VoidCallback? onAction}) {
  final messenger = messengerKey.currentState;
  if (messenger == null || message.isEmpty) return;
  final wide = MediaQuery.maybeSizeOf(messenger.context)?.width ?? 0;
  final (icon, color) = switch (kind) {
    ToastKind.success => (AppIcons.success, AppColors.dark.success),
    ToastKind.error => (AppIcons.error, AppColors.dark.danger),
    ToastKind.info => (AppIcons.bellFill, AppColors.dark.brand),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      width: wide >= kWideBreakpoint ? 460 : null,
      duration: Duration(seconds: actionLabel == null ? 4 : 6),
      content: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}

void toastOk(String message) => toast(message, kind: ToastKind.success);

void toastError(Object error) => toast(errorText(error), kind: ToastKind.error);

/// Opens a screen. [path] becomes the browser address on the web
/// (e.g. `/tools/<id>`), so the page can be refreshed or shared.
///
/// A second tap within half a second (a double tap, or a tap while the
/// first page is still sliding in) is ignored, so one tap opens one page.
Future<T?> push<T>(BuildContext context, Widget page, {String? path}) {
  final now = DateTime.now();
  if (now.difference(_lastPush) < const Duration(milliseconds: 500)) return Future<T?>.value();
  _lastPush = now;
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page, settings: RouteSettings(name: path)));
}

DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

/// Which top-level section is showing: a dock tab on phones, a sidebar or
/// header link on the website. Signed out the sections are the public
/// site's pages; signed in they are the role's sections (see `shell.dart`).
///
/// On the web the section is mirrored in the address bar (…/#/tools), so a
/// refresh or a shared link opens the same page.
abstract final class SiteNav {
  static final ValueNotifier<String> section = ValueNotifier('home');

  /// The address the app was opened at (`/` outside a browser).
  static String initialRoute = '/';

  /// Reads the starting address. Call once from `main()` before `runApp`:
  /// the browser's address is only reliable until the navigator takes over.
  static void init() {
    initialRoute = PlatformDispatcher.instance.defaultRouteName;
    section.value = sectionOf(initialRoute);
  }

  /// Role to preselect on the sign-up page ("Become a technician" links).
  static String? signupRole;

  /// Category to preselect when a directory page opens from a category tile.
  static String? presetCategory;

  /// First path segment: `/tools/abc?x=1` → `tools`; `/` → `home`.
  static String sectionOf(String route) {
    final segments = Uri.parse(route).pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? 'home' : segments.first;
  }

  /// Switches section from anywhere: closes pushed pages first so the
  /// section is what the user sees.
  static void go(String key) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    select(key);
  }

  /// Switches section without touching the page stack.
  static void select(String key) {
    // Close the keyboard: what was typed belongs to the section being left.
    if (key != section.value) FocusManager.instance.primaryFocus?.unfocus();
    section.value = key;
    syncUrl();
  }

  static void syncUrl() {
    if (!kIsWeb) return;
    final key = section.value;
    SystemNavigator.routeInformationUpdated(uri: Uri(path: key == 'home' ? '/' : '/$key'), replace: true);
  }
}

/// Puts the section back in the address bar when the last pushed page
/// closes (the navigator itself would report the root route's bare "/").
class SectionUrlObserver extends NavigatorObserver {
  void _sync(Route<dynamic>? nowOnTop) {
    if (nowOnTop?.isFirst ?? false) WidgetsBinding.instance.addPostFrameCallback((_) => SiteNav.syncUrl());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(previousRoute);
}
