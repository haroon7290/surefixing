import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/badge_service.dart';
import '../services/realtime_service.dart';
import '../services/site_nav.dart';
import '../widgets/states.dart';
import '../widgets/visuals.dart';
import 'admin/admin_kyc.dart';
import 'admin/admin_overview.dart';
import 'admin/admin_reports.dart';
import 'admin/admin_users.dart';
import 'client/client_dashboard.dart';
import 'client/my_jobs_screen.dart';
import 'shared/account_screen.dart';
import 'shared/inbox_screen.dart';
import 'shared/tools_market_screen.dart';
import 'supplier/my_tools_screen.dart';
import 'supplier/rental_requests_screen.dart';
import 'supplier/supplier_dashboard.dart';
import 'technician/find_jobs_screen.dart';
import 'technician/my_work_screen.dart';
import 'technician/tech_dashboard.dart';

class ShellTab {
  /// Section key: shared with SiteNav and shown in the web address bar.
  final String key;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget Function() build;
  final ValueNotifier<int>? badge;

  /// Dashboards lay themselves out for wide windows; other tabs are
  /// centred in a column by the shell.
  final bool fullWidth;
  const ShellTab(this.key, this.label, this.icon, this.activeIcon, this.build, {this.badge, this.fullWidth = false});
}

/// Signed-in home for the user's role: bottom navigation on phones; on
/// wide windows the site header (see web/site_header.dart) switches tabs.
class HomeShell extends StatefulWidget {
  final String role;
  const HomeShell({super.key, required this.role});

  /// Lets a page switch tabs, e.g. the dashboard's "See all jobs".
  static void goTo(BuildContext context, int index) {
    final tabs = context.findAncestorStateOfType<_HomeShellState>()?._tabs;
    if (tabs != null && index >= 0 && index < tabs.length) SiteNav.go(tabs[index].key);
  }

  @override
  State<HomeShell> createState() => _HomeShellState();

  static List<ShellTab> tabsFor(String role) {
    final msgs = BadgeService.instance.unreadMessages;
    switch (role) {
      case 'technician':
        return [
          ShellTab('home', 'Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, () => const TechDashboard(),
              fullWidth: true),
          ShellTab('find-work', 'Find work', Icons.search_rounded, Icons.manage_search_rounded, () => const FindJobsScreen()),
          ShellTab('my-jobs', 'My jobs', Icons.work_outline_rounded, Icons.work_rounded, () => const MyWorkScreen()),
          ShellTab('messages', 'Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, () => const InboxScreen(),
              badge: msgs),
          ShellTab('account', 'Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      case 'supplier':
        return [
          ShellTab('home', 'Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, () => const SupplierDashboard(),
              fullWidth: true),
          ShellTab('my-tools', 'My tools', Icons.handyman_outlined, Icons.handyman_rounded, () => const MyToolsScreen()),
          ShellTab('requests', 'Requests', Icons.inbox_outlined, Icons.inbox_rounded, () => const RentalRequestsScreen()),
          ShellTab('account', 'Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      case 'admin':
        return [
          ShellTab('home', 'Overview', Icons.insights_outlined, Icons.insights_rounded, () => const AdminOverview(), fullWidth: true),
          ShellTab('users', 'Users', Icons.group_outlined, Icons.group_rounded, () => const AdminUsers()),
          ShellTab('verify', 'Verify', Icons.verified_user_outlined, Icons.verified_user_rounded, () => const AdminKyc()),
          ShellTab('reports', 'Reports', Icons.flag_outlined, Icons.flag_rounded, () => const AdminReports()),
          ShellTab('account', 'Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      default:
        return [
          ShellTab('home', 'Home', Icons.home_outlined, Icons.home_rounded, () => const ClientDashboard(), fullWidth: true),
          ShellTab('my-jobs', 'My jobs', Icons.work_outline_rounded, Icons.work_rounded, () => const MyJobsScreen()),
          ShellTab('tools', 'Tools', Icons.handyman_outlined, Icons.handyman_rounded, () => const ToolsMarketScreen()),
          ShellTab('messages', 'Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, () => const InboxScreen(),
              badge: msgs),
          ShellTab('account', 'Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
    }
  }
}

class _HomeShellState extends State<HomeShell> {
  late final List<ShellTab> _tabs = HomeShell.tabsFor(widget.role);
  final Set<int> _built = {};

  @override
  void initState() {
    super.initState();
    SiteNav.section.addListener(_onSection);
  }

  @override
  void dispose() {
    SiteNav.section.removeListener(_onSection);
    super.dispose();
  }

  void _onSection() => setState(() {});

  // Unknown keys (e.g. a public-site link) fall back to the first tab.
  int get _index => _tabs.indexWhere((t) => t.key == SiteNav.section.value).clamp(0, _tabs.length - 1);

  @override
  Widget build(BuildContext context) {
    final index = _index;
    _built.add(index);
    final wide = context.isWide;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  // Tabs are built on first visit, then kept alive.
                  !_built.contains(i)
                      ? const SizedBox.shrink()
                      : wide && !_tabs[i].fullWidth
                          ? WebContent(maxWidth: 1100, gutter: 24, child: _tabs[i].build())
                          : _tabs[i].build(),
              ],
            ),
          ),
          OfflineBanner(connected: RealtimeService.instance.connected),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.border))),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => SiteNav.select(_tabs[i].key),
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: t.badge == null ? Icon(t.icon) : BadgeIcon(icon: t.icon, count: t.badge!),
                      selectedIcon: t.badge == null ? Icon(t.activeIcon) : BadgeIcon(icon: t.activeIcon, count: t.badge!),
                      label: t.label,
                    ),
                ],
              ),
            ),
    );
  }
}
