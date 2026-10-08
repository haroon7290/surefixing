import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/badge_service.dart';
import '../services/realtime_service.dart';
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
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget Function() build;
  final ValueNotifier<int>? badge;
  const ShellTab(this.label, this.icon, this.activeIcon, this.build, {this.badge});
}

/// Bottom-navigation home for the signed-in user's role.
class HomeShell extends StatefulWidget {
  final String role;
  const HomeShell({super.key, required this.role});

  /// Lets a page switch tabs, e.g. the dashboard's "See all jobs".
  static void goTo(BuildContext context, int index) => context.findAncestorStateOfType<_HomeShellState>()?._select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _built = {0};
  late final List<ShellTab> _tabs = _tabsFor(widget.role);

  static List<ShellTab> _tabsFor(String role) {
    final msgs = BadgeService.instance.unreadMessages;
    switch (role) {
      case 'technician':
        return [
          ShellTab('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, () => const TechDashboard()),
          ShellTab('Find work', Icons.search_rounded, Icons.manage_search_rounded, () => const FindJobsScreen()),
          ShellTab('My jobs', Icons.work_outline_rounded, Icons.work_rounded, () => const MyWorkScreen()),
          ShellTab('Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, () => const InboxScreen(), badge: msgs),
          ShellTab('Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      case 'supplier':
        return [
          ShellTab('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, () => const SupplierDashboard()),
          ShellTab('My tools', Icons.handyman_outlined, Icons.handyman_rounded, () => const MyToolsScreen()),
          ShellTab('Requests', Icons.inbox_outlined, Icons.inbox_rounded, () => const RentalRequestsScreen()),
          ShellTab('Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      case 'admin':
        return [
          ShellTab('Overview', Icons.insights_outlined, Icons.insights_rounded, () => const AdminOverview()),
          ShellTab('Users', Icons.group_outlined, Icons.group_rounded, () => const AdminUsers()),
          ShellTab('Verify', Icons.verified_user_outlined, Icons.verified_user_rounded, () => const AdminKyc()),
          ShellTab('Reports', Icons.flag_outlined, Icons.flag_rounded, () => const AdminReports()),
          ShellTab('Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
      default:
        return [
          ShellTab('Home', Icons.home_outlined, Icons.home_rounded, () => const ClientDashboard()),
          ShellTab('My jobs', Icons.work_outline_rounded, Icons.work_rounded, () => const MyJobsScreen()),
          ShellTab('Tools', Icons.handyman_outlined, Icons.handyman_rounded, () => const ToolsMarketScreen()),
          ShellTab('Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, () => const InboxScreen(), badge: msgs),
          ShellTab('Account', Icons.person_outline_rounded, Icons.person_rounded, () => const AccountScreen()),
        ];
    }
  }

  void _select(int i) {
    if (i < 0 || i >= _tabs.length) return;
    setState(() {
      _index = i;
      _built.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  // Tabs are built on first visit, then kept alive.
                  _built.contains(i) ? _tabs[i].build() : const SizedBox.shrink(),
              ],
            ),
          ),
          OfflineBanner(connected: RealtimeService.instance.connected),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.border))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
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
