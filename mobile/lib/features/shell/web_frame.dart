import 'package:flutter/material.dart';

import '../../kit.dart';
import '../site/site_header.dart';
import 'shell.dart';

/// Wraps the whole app (MaterialApp.builder). On wide windows it puts the
/// persistent chrome around the navigator — the sidebar when signed in, the
/// site header when signed out — so every page, pushed screen and dialog
/// shows inside it. On phones it adds nothing.
///
/// The chrome lives above the navigator, so it gets its own Overlay for
/// tooltips and menus. The navigator keeps its place in the tree when the
/// window crosses the breakpoint, so no state is lost on resize.
class WebFrame extends StatefulWidget {
  final Widget child;
  const WebFrame({super.key, required this.child});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final ValueNotifier<Widget> _child = ValueNotifier(widget.child);
  final _navigatorHost = GlobalKey();

  // The browser focuses the app before the first layout; Flutter then sorts
  // every focusable widget by position, which fails for chrome buttons not
  // laid out yet. So the chrome's buttons arrive one frame later (a
  // same-size placeholder keeps the page from jumping).
  final ValueNotifier<bool> _ready = ValueNotifier(false);

  late final OverlayEntry _entry = OverlayEntry(
    maintainState: true,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([_child, _ready, Session.instance]),
      builder: (context, _) {
        final wide = context.isWide;
        final signedIn = Session.instance.loggedIn;
        // Routes paint a modal barrier with BlockSemantics, which would hide
        // the chrome (painted earlier) from screen readers. A separate
        // semantics container keeps that blocking inside.
        final page = KeyedSubtree(key: _navigatorHost, child: Semantics(container: true, child: _child.value));
        return Row(children: [
          if (wide && signedIn) _ready.value ? const Sidebar() : const SizedBox(width: Sidebar.width),
          Expanded(
            child: Column(children: [
              if (wide && !signedIn) _ready.value ? const SiteHeader() : const SizedBox(height: SiteHeader.height),
              Expanded(child: page),
            ]),
          ),
        ]);
      },
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ready.value = true);
  }

  @override
  void didUpdateWidget(covariant WebFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child.value = widget.child;
  }

  @override
  void dispose() {
    _child.dispose();
    _ready.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(data: context.isWide ? wideTheme(base) : base, child: Overlay(initialEntries: [_entry]));
  }
}

/// The signed-in website's navigation: every section of the role, the
/// wallet balance, and the account menu.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const double width = 256;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([Session.instance, SiteNav.section]),
      builder: (context, _) {
        final user = Session.instance.user;
        if (user == null) return const SizedBox(width: width);
        final dests = destinationsFor(user.role);
        final groups = <String, List<Dest>>{};
        for (final d in dests) {
          groups.putIfAbsent(d.group, () => []).add(d);
        }
        final dark = AppColors.light.canvas; // text on the dark rail
        return Material(
          color: context.isDark ? const Color(0xFF090A0C) : c.hero,
          child: SizedBox(
            width: width,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(onTap: () => SiteNav.go('home'), borderRadius: BorderRadius.circular(8), child: const BrandLogo(size: 30, onDark: true)),
                ),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), children: [
                  for (final entry in groups.entries) ...[
                    if (entry.key.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                        child: Text(entry.key.toUpperCase(),
                            style: TextStyle(fontFamily: kBodyFont, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: dark.withValues(alpha: 0.38))),
                      ),
                    for (final d in entry.value) _RailItem(d, active: SiteNav.section.value == d.key),
                  ],
                ]),
              ),
              if (!user.isAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: _RailWallet(balance: user.walletBalance),
                ),
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 14), child: _RailUser(user)),
            ]),
          ),
        );
      },
    );
  }
}

class _RailItem extends StatefulWidget {
  final Dest dest;
  final bool active;
  const _RailItem(this.dest, {required this.active});

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.dest;
    final light = AppColors.light.canvas;
    final fg = widget.active ? c.onBrand : light.withValues(alpha: _hover ? 1 : 0.72);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: d.label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => SiteNav.go(d.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: widget.active ? c.brand : (_hover ? light.withValues(alpha: 0.07) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(widget.active ? d.activeIcon : d.icon, size: 20, color: fg),
                Gap.w12,
                Expanded(
                  child: Text(d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: kBodyFont, fontSize: 14, fontWeight: widget.active ? FontWeight.w800 : FontWeight.w600, color: fg, height: 1.2)),
                ),
                if (d.badge != null)
                  ValueListenableBuilder<int>(
                    valueListenable: d.badge!,
                    builder: (context, n, _) => n <= 0
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: widget.active ? c.onBrand : c.brand, borderRadius: BorderRadius.circular(10)),
                            child: Text(n > 99 ? '99+' : '$n',
                                style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, color: widget.active ? c.brand : c.onBrand, height: 1.1)),
                          ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailWallet extends StatelessWidget {
  final double balance;
  const _RailWallet({required this.balance});

  @override
  Widget build(BuildContext context) {
    final light = AppColors.light.canvas;
    return Semantics(
      button: true,
      label: 'Wallet balance ${money(balance)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => SiteNav.go('wallet'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: light.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: light.withValues(alpha: 0.08))),
          child: Row(children: [
            Icon(AppIcons.walletFill, size: 20, color: context.colors.brand),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Wallet', style: TextStyle(fontFamily: kBodyFont, fontSize: 11.5, fontWeight: FontWeight.w600, color: light.withValues(alpha: 0.55))),
                Text(money(balance), style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: light, letterSpacing: -0.3, height: 1.2)),
              ]),
            ),
            Icon(AppIcons.arrowUpRight, size: 14, color: light.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}

/// Name, role and a menu (dark mode, sign out). Tapping the name opens the
/// account page. The sidebar sits above the page navigator, so the menu is
/// a [MenuAnchor] (it only needs an overlay, which the frame provides).
class _RailUser extends StatelessWidget {
  final User user;
  const _RailUser(this.user);

  Future<void> _signOut() async {
    final ctx = navigatorKey.currentContext;
    if (ctx != null && await confirm(ctx, title: 'Sign out?', message: 'You can sign back in any time.', confirmLabel: 'Sign out', icon: AppIcons.logout)) {
      await Session.instance.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = AppColors.light.canvas;
    final dark = context.isDark;
    final active = SiteNav.section.value == 'account';
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: active ? light.withValues(alpha: 0.1) : Colors.transparent),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Account: ${user.name}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => SiteNav.go('account'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Avatar(name: user.name, image: user.avatar, size: 38),
                  Gap.w12,
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, fontSize: 14, fontWeight: FontWeight.w700, color: light, height: 1.25)),
                      Text(roleLabels[user.role] ?? user.role,
                          maxLines: 1, style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w500, color: light.withValues(alpha: 0.55), height: 1.25)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        MenuAnchor(
          alignmentOffset: const Offset(-150, 0),
          menuChildren: [
            MenuItemButton(leadingIcon: const Icon(AppIcons.account, size: 18), onPressed: () => SiteNav.go('account'), child: const Text('Account & settings')),
            MenuItemButton(
              leadingIcon: Icon(dark ? AppIcons.sun : AppIcons.moon, size: 18),
              onPressed: () => Settings.instance.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
              child: Text(dark ? 'Light mode' : 'Dark mode'),
            ),
            const Divider(height: 8),
            MenuItemButton(leadingIcon: const Icon(AppIcons.logout, size: 18), onPressed: _signOut, child: const Text('Sign out')),
          ],
          builder: (context, menu, _) => IconButton(
            tooltip: 'Account menu',
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            icon: Icon(AppIcons.dots, size: 18, color: light.withValues(alpha: 0.7)),
          ),
        ),
        Gap.w4,
      ]),
    );
  }
}
