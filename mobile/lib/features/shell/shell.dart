import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kit.dart';
import '../account/account_screen.dart';
import '../account/notifications_screen.dart';
import '../account/saved_screen.dart';
import '../admin/admin_lists.dart';
import '../admin/admin_overview.dart';
import '../admin/admin_users.dart';
import '../chat/inbox_screen.dart';
import '../home/client_home.dart';
import '../home/supplier_home.dart';
import '../home/technician_home.dart';
import '../jobs/find_jobs_screen.dart';
import '../jobs/my_jobs_screen.dart';
import '../jobs/smart_match_screen.dart';
import '../rentals/rentals_screens.dart';
import '../technicians/technicians_screen.dart';
import '../tools/my_tools_screen.dart';
import '../tools/tool_market_screen.dart';
import '../wallet/wallet_screen.dart';

/// A top-level section of the signed-in app. [dock] sections are the tabs
/// of the phone's floating dock; the website sidebar lists them all.
class Dest {
  final String key;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
  final bool dock;
  final String group;
  final ValueListenable<int>? badge;
  const Dest(this.key, this.label, this.icon, this.activeIcon, this.builder, {this.dock = false, this.group = '', this.badge});
}

List<Dest> destinationsFor(String role) {
  final messages = Dest('messages', 'Messages', AppIcons.chat, AppIcons.chatFill, (_) => const InboxScreen(), dock: true, group: 'Activity', badge: Badges.instance.messages);
  final alerts = Dest('notifications', 'Notifications', AppIcons.bell, AppIcons.bellFill, (_) => const NotificationsScreen(), group: 'Activity', badge: Badges.instance.notifications);
  final wallet = Dest('wallet', 'Wallet', AppIcons.wallet, AppIcons.walletFill, (_) => const WalletScreen(), group: 'Activity');
  final account = Dest('account', 'Account', AppIcons.account, AppIcons.accountFill, (_) => const AccountScreen(), dock: true, group: 'Account');
  return switch (role) {
    'technician' => [
        Dest('home', 'Home', AppIcons.home, AppIcons.homeFill, (_) => const TechnicianHome(), dock: true),
        Dest('find', 'Find jobs', AppIcons.search, AppIcons.searchFill, (_) => const FindJobsScreen(), dock: true),
        Dest('work', 'My work', AppIcons.work, AppIcons.workFill, (_) => const MyWorkScreen(), dock: true),
        Dest('tools', 'Rent tools', AppIcons.tools, AppIcons.toolsFill, (_) => const ToolMarketScreen()),
        Dest('rentals', 'My rentals', AppIcons.rentals, AppIcons.rentalsFill, (_) => const MyRentalsScreen()),
        messages,
        alerts,
        wallet,
        account,
      ],
    'supplier' => [
        Dest('home', 'Home', AppIcons.home, AppIcons.homeFill, (_) => const SupplierHome(), dock: true),
        Dest('inventory', 'My tools', AppIcons.tools, AppIcons.toolsFill, (_) => const MyToolsScreen(), dock: true),
        Dest('orders', 'Orders', AppIcons.orders, AppIcons.ordersFill, (_) => const OrdersScreen(), dock: true),
        messages,
        alerts,
        wallet,
        account,
      ],
    'admin' => [
        Dest('home', 'Overview', AppIcons.dashboard, AppIcons.dashboardFill, (_) => const AdminOverview(), dock: true),
        Dest('users', 'Users', AppIcons.users, AppIcons.usersFill, (_) => const AdminUsersScreen(), dock: true),
        Dest('verify', 'Verify', AppIcons.verify, AppIcons.verifyFill, (_) => const AdminKycScreen(), dock: true),
        Dest('reports', 'Reports', AppIcons.reports, AppIcons.reportsFill, (_) => const AdminReportsScreen(), dock: true),
        Dest('all-jobs', 'Jobs', AppIcons.jobs, AppIcons.jobsFill, (_) => const AdminJobsScreen(), group: 'Marketplace'),
        Dest('all-tools', 'Tools', AppIcons.tools, AppIcons.toolsFill, (_) => const AdminToolsScreen(), group: 'Marketplace'),
        Dest('payments', 'Payments', AppIcons.payments, AppIcons.paymentsFill, (_) => const AdminPaymentsScreen(), group: 'Marketplace'),
        alerts,
        account,
      ],
    _ => [
        Dest('home', 'Home', AppIcons.home, AppIcons.homeFill, (_) => const ClientHome(), dock: true),
        Dest('jobs', 'My jobs', AppIcons.jobs, AppIcons.jobsFill, (_) => const MyJobsScreen(), dock: true),
        Dest('match', 'Smart Match', AppIcons.sparkle, AppIcons.sparkleFill, (_) => const SmartMatchScreen()),
        Dest('technicians', 'Technicians', AppIcons.technicians, AppIcons.techniciansFill, (_) => const TechniciansScreen()),
        Dest('tools', 'Rent tools', AppIcons.tools, AppIcons.toolsFill, (_) => const ToolMarketScreen(), dock: true),
        Dest('rentals', 'My rentals', AppIcons.rentals, AppIcons.rentalsFill, (_) => const MyRentalsScreen()),
        messages,
        alerts,
        wallet,
        Dest('saved', 'Saved', AppIcons.heart, AppIcons.heartFill, (_) => const SavedScreen(), group: 'Activity'),
        account,
      ],
  };
}

/// Goes to a section from anywhere inside the app. On the website every
/// section is a sidebar page; on phones the ones outside the dock open as
/// a page with a back button.
void openSection(BuildContext context, String key) {
  final dests = destinationsFor(Session.instance.role);
  final dest = dests.where((d) => d.key == key).firstOrNull;
  if (dest == null) return;
  if (context.isWide || dest.dock) {
    SiteNav.go(key);
  } else {
    push(context, dest.builder(context), path: '/$key');
  }
}

/// The signed-in app: the current section's screen, plus the floating dock
/// on phones. (On wide windows the sidebar lives in `WebFrame`, above the
/// navigator, so it stays put while pages open.)
class HomeShell extends StatefulWidget {
  final String role;
  const HomeShell({super.key, required this.role});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final List<Dest> _dests = destinationsFor(widget.role);
  final Set<String> _visited = {};

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: SiteNav.section,
        builder: (context, section, _) {
          var index = _dests.indexWhere((d) => d.key == section);
          if (index < 0) index = 0;
          final current = _dests[index];
          _visited.add(current.key);
          // Sections are built on first visit and then kept alive, so
          // switching back is instant and keeps scroll position.
          final stack = IndexedStack(index: index, children: [
            for (final d in _dests) _visited.contains(d.key) ? KeyedSubtree(key: ValueKey(d.key), child: d.builder(context)) : const SizedBox.shrink(),
          ]);
          final body = Column(children: [const OfflineBanner(), Expanded(child: stack)]);
          if (context.isWide) return Material(color: context.colors.canvas, child: body);
          return Scaffold(
            extendBody: true,
            body: body,
            bottomNavigationBar: Dock(items: _dests.where((d) => d.dock).toList(), current: current.key),
          );
        },
      );
}

/// The phone's floating navigation: a dark capsule with an orange marker
/// on the current tab.
class Dock extends StatelessWidget {
  final List<Dest> items;
  final String current;
  const Dock({super.key, required this.items, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, math.max(safe, 12)),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: c.hero,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.heroLine),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: [for (final d in items) Expanded(child: _DockItem(d, active: d.key == current))]),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final Dest dest;
  final bool active;
  const _DockItem(this.dest, {required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget icon = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 50,
      height: 30,
      decoration: BoxDecoration(color: active ? c.brand : Colors.transparent, borderRadius: BorderRadius.circular(15)),
      child: Icon(active ? dest.activeIcon : dest.icon, size: 21, color: active ? c.onBrand : c.onHeroMuted),
    );
    if (dest.badge != null) {
      icon = ValueListenableBuilder<int>(
        valueListenable: dest.badge!,
        builder: (context, n, child) => Stack(clipBehavior: Clip.none, children: [
          child!,
          if (n > 0) Positioned(right: 2, top: -5, child: CountBadge(n)),
        ]),
        child: icon,
      );
    }
    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => SiteNav.go(dest.key),
        radius: 36,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(height: 5),
          Text(
            dest.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kBodyFont, fontSize: 10.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? c.onHero : c.onHeroMuted, height: 1.1),
          ),
        ]),
      ),
    );
  }
}
