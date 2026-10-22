import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../services/site_nav.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../shared/technicians_list_screen.dart';
import '../shared/tools_market_screen.dart';
import 'about_page.dart';
import 'landing_page.dart';

/// The signed-out website on wide windows: one page per header section.
class PublicSite extends StatelessWidget {
  const PublicSite({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: SiteNav.section,
        builder: (context, section, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(section), child: _page(section)),
        ),
      );

  Widget _page(String section) => switch (section) {
        'technicians' => const WebPage(maxWidth: 1200, child: TechniciansListScreen()),
        'tools' => const WebPage(maxWidth: 1200, child: ToolsMarketScreen()),
        'about' => const AboutPage(),
        'login' => const LoginScreen(),
        'register' => RegisterScreen(initialRole: SiteNav.signupRole),
        _ => const LandingPage(),
      };
}
