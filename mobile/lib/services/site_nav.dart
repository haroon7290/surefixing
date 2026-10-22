import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'navigation.dart';

/// Which top-level section is showing: a bottom-navigation tab on phones,
/// a header link on the website. Signed out the sections are the public
/// site's pages (home, technicians, tools, about, login, register);
/// signed in they are the role's tabs (see HomeShell.tabsFor).
///
/// On the web the section is mirrored in the address bar (…/#/tools), so a
/// refresh or a shared link opens the same page.
class SiteNav {
  SiteNav._();

  static final ValueNotifier<String> section = ValueNotifier(_initialSection());

  /// Role to preselect on the sign-up page ("Become a technician" links).
  static String? signupRole;

  /// Landing-page anchor to scroll to after navigating home.
  static final ValueNotifier<String?> anchor = ValueNotifier(null);

  static String _initialSection() {
    if (!kIsWeb) return 'home';
    final path = PlatformDispatcher.instance.defaultRouteName.split('?').first;
    final key = path.replaceAll('/', '').trim();
    return key.isEmpty ? 'home' : key;
  }

  /// Switches section from anywhere (header links, buttons inside pages):
  /// closes pushed pages first so the section is what the user sees.
  static void go(String key, {String? anchor}) {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    select(key);
    if (anchor != null) SiteNav.anchor.value = anchor;
  }

  /// Switches section without touching the page stack (tab bar taps).
  static void select(String key) {
    section.value = key;
    syncUrl();
  }

  static void syncUrl() {
    if (!kIsWeb) return;
    final key = section.value;
    SystemNavigator.routeInformationUpdated(uri: Uri(path: key == 'home' ? '/' : '/$key'), replace: true);
  }
}
