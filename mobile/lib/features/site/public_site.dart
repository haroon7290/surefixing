import 'package:flutter/material.dart';

import '../../kit.dart';
import '../auth/auth_screens.dart';
import '../technicians/technicians_screen.dart';
import '../tools/tool_market_screen.dart';
import 'info_pages.dart';
import 'landing_page.dart';
import 'site_header.dart';

/// The signed-out website: landing page, public directories, how it works
/// and the sign-in pages. On wide windows the header comes from `WebFrame`;
/// on phones this adds a compact top bar.
class PublicSite extends StatelessWidget {
  const PublicSite({super.key});

  static const authSections = {'login', 'register', 'forgot'};

  static Widget pageFor(String section) => switch (section) {
        'technicians' => const TechniciansScreen(),
        'tools' => const ToolMarketScreen(),
        'about' => const AboutPage(),
        'help' => const HelpPage(),
        'terms' => const LegalPage(),
        'privacy' => const LegalPage(privacy: true),
        'login' => const LoginScreen(),
        'register' => const RegisterScreen(),
        'forgot' => const ForgotPasswordScreen(),
        _ => const LandingPage(),
      };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: SiteNav.section,
        builder: (context, section, _) {
          final auth = authSections.contains(section);
          final page = KeyedSubtree(key: ValueKey(section), child: pageFor(section));
          final framed = PageFrame(hideBar: !context.isWide, footer: auth ? null : (_) => const SiteFooter(), child: page);
          if (context.isWide) return Material(color: context.colors.canvas, child: framed);
          return Scaffold(appBar: const SiteTopBar(), body: framed);
        },
      );
}
