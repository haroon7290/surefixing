import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/settings_service.dart';
import '../../services/site_nav.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../client/post_job_screen.dart';
import '../shared/my_rentals_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/technician_profile_screen.dart';
import '../shared/technicians_list_screen.dart';
import '../shared/tools_market_screen.dart';
import '../shells.dart';
import '../supplier/tool_form_screen.dart';

/// Opens a page from the header, which sits above the navigator.
void _open(Widget page) {
  final ctx = navigatorKey.currentContext;
  if (ctx != null) push(ctx, page);
}

/// The website's top navigation bar: public links when signed out, the
/// role's sections plus notifications and an account menu when signed in.
class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key});

  static const height = 72.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      child: Container(
        height: height,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
        child: WebContent(
          maxWidth: 1240,
          child: ListenableBuilder(
            listenable: Listenable.merge([AuthService.instance, SiteNav.section]),
            builder: (context, _) {
              final user = AuthService.instance.user;
              final section = SiteNav.section.value;
              return Row(
                children: [
                  _Brand(onTap: () => SiteNav.go('home')),
                  const SizedBox(width: 28),
                  Expanded(child: user == null ? _PublicLinks(section: section) : _RoleLinks(user: user, section: section)),
                  const SizedBox(width: 12),
                  if (user == null) const _PublicActions() else _UserActions(user: user),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final VoidCallback onTap;
  const _Brand({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'SureFix home',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [LogoMark(size: 36), SizedBox(width: 10), Wordmark(size: 22)]),
          ),
        ),
      );
}

/// A header link with an underline when its section is showing.
class NavLink extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ValueNotifier<int>? badge;
  const NavLink({super.key, required this.label, required this.onTap, this.active = false, this.badge});

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final text = Text(
      label,
      style: TextStyle(
        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
        fontSize: 14.5,
        color: active ? primary : context.palette.muted,
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: SiteHeader.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? primary : Colors.transparent, width: 3)),
          ),
          alignment: Alignment.center,
          child: badge == null
              ? text
              : ValueListenableBuilder<int>(
                  valueListenable: badge!,
                  builder: (_, n, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                    text,
                    if (n > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: context.palette.danger, borderRadius: BorderRadius.circular(10)),
                        child: Text(n > 99 ? '99+' : '$n',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                ),
        ),
      ),
    );
  }
}

// Links take the section as a field (not const) so they rebuild with it.
class _PublicLinks extends StatelessWidget {
  final String section;
  const _PublicLinks({required this.section});

  @override
  Widget build(BuildContext context) {
    final s = section;
    // Anchor links only fit on roomier windows.
    final roomy = MediaQuery.sizeOf(context).width >= 1240;
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          NavLink(label: 'Home', active: s == 'home', onTap: () => SiteNav.go('home')),
          if (roomy) NavLink(label: 'Services', onTap: () => SiteNav.go('home', anchor: 'services')),
          if (roomy) NavLink(label: 'How it works', onTap: () => SiteNav.go('home', anchor: 'how')),
          NavLink(label: 'Technicians', active: s == 'technicians', onTap: () => SiteNav.go('technicians')),
          NavLink(label: 'Rent tools', active: s == 'tools', onTap: () => SiteNav.go('tools')),
          NavLink(label: 'About', active: s == 'about', onTap: () => SiteNav.go('about')),
        ]));
  }
}

class _PublicActions extends StatelessWidget {
  const _PublicActions();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const ThemeToggle(),
        const SizedBox(width: 4),
        TextButton(onPressed: () => SiteNav.go('login'), child: const Text('Log in')),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
          onPressed: () {
            SiteNav.signupRole = null;
            SiteNav.go('register');
          },
          child: const Text('Get started'),
        ),
      ]);
}

class _RoleLinks extends StatelessWidget {
  final User user;
  final String section;
  const _RoleLinks({required this.user, required this.section});

  @override
  Widget build(BuildContext context) {
    final s = section;
    final tabs = HomeShell.tabsFor(user.role).where((t) => t.key != 'account').toList();
    // Unknown section → the first tab is showing (see HomeShell).
    final activeKey = tabs.any((t) => t.key == s) || s == 'account' ? s : tabs.first.key;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final t in tabs) NavLink(label: t.label, active: t.key == activeKey, badge: t.badge, onTap: () => SiteNav.go(t.key)),
        if (user.isClient) NavLink(label: 'Technicians', onTap: () => _open(const TechniciansListScreen())),
        if (user.isTechnician) NavLink(label: 'Rent tools', onTap: () => _open(const ToolsMarketScreen())),
      ]),
    );
  }
}

class _UserActions extends StatelessWidget {
  final User user;
  const _UserActions({required this.user});

  @override
  Widget build(BuildContext context) {
    final cta = user.isClient
        ? ('Post a job', Icons.add_rounded, () => _open(const PostJobScreen()))
        : user.isSupplier
            ? ('List a tool', Icons.add_rounded, () => _open(const ToolFormScreen()))
            : null;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (cta != null) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: cta.$3,
          icon: Icon(cta.$2, size: 20),
          label: Text(cta.$1),
        ),
        const SizedBox(width: 8),
      ],
      IconButton(
        tooltip: 'Notifications',
        onPressed: () async {
          final ctx = navigatorKey.currentContext;
          if (ctx == null) return;
          await push(ctx, const NotificationsScreen());
          BadgeService.instance.refresh();
        },
        icon: ValueListenableBuilder<int>(
          valueListenable: BadgeService.instance.unreadNotifications,
          builder: (_, n, __) => Badge(
            isLabelVisible: n > 0,
            label: Text(n > 99 ? '99+' : '$n'),
            backgroundColor: context.palette.danger,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ),
      const SizedBox(width: 4),
      _AccountMenu(user: user),
    ]);
  }
}

class _AccountMenu extends StatelessWidget {
  final User user;
  const _AccountMenu({required this.user});

  Future<void> _logout() async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final ok = await confirmDialog(ctx, title: 'Log out?', confirm: 'Log out');
    if (ok) await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 6),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border))),
        backgroundColor: WidgetStatePropertyAll(p.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: SizedBox(
            width: 220,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name, style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
              Text(user.email, style: TextStyle(color: p.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.manage_accounts_outlined),
          onPressed: () => SiteNav.go('account'),
          child: const Text('Account & settings'),
        ),
        if (user.isTechnician)
          MenuItemButton(
            leadingIcon: const Icon(Icons.visibility_outlined),
            onPressed: () => _open(TechnicianProfileScreen(technicianId: user.id)),
            child: const Text('My public profile'),
          ),
        if (user.isClient || user.isTechnician)
          MenuItemButton(
            leadingIcon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _open(const MyRentalsScreen()),
            child: const Text('My tool rentals'),
          ),
        MenuItemButton(
          leadingIcon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => SettingsService.instance.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
          child: Text(dark ? 'Light mode' : 'Dark mode'),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: Icon(Icons.logout_rounded, color: p.danger),
          onPressed: _logout,
          child: Text('Log out', style: TextStyle(color: p.danger)),
        ),
      ],
      builder: (context, controller, _) => Semantics(
        button: true,
        label: 'Account menu',
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppAvatar(name: user.name, url: user.avatar, size: 36),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(user.firstName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.expand_more_rounded, color: p.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Light/dark switch used on the public site.
class ThemeToggle extends StatelessWidget {
  final Color? color;
  const ThemeToggle({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      color: color,
      onPressed: () => SettingsService.instance.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
