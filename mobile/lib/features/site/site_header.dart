import 'package:flutter/material.dart';

import '../../kit.dart';

const _links = [('home', 'Home'), ('technicians', 'Find technicians'), ('tools', 'Rent tools'), ('about', 'How it works')];

void _toggleTheme(BuildContext context) => Settings.instance.setThemeMode(context.isDark ? ThemeMode.light : ThemeMode.dark);

/// The public website's header on wide windows (lives in `WebFrame`).
class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key});

  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.canvas,
      child: Container(
        height: height,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1264),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ValueListenableBuilder<String>(
                valueListenable: SiteNav.section,
                builder: (context, section, _) => Row(children: [
                  InkWell(onTap: () => SiteNav.go('home'), borderRadius: BorderRadius.circular(8), child: const BrandLogo(size: 32)),
                  const Spacer(),
                  for (final (key, label) in _links) _HeaderLink(label, active: section == key, onTap: () => SiteNav.go(key)),
                  const Spacer(),
                  IconButton(
                    tooltip: context.isDark ? 'Light mode' : 'Dark mode',
                    onPressed: () => _toggleTheme(context),
                    icon: Icon(context.isDark ? AppIcons.sun : AppIcons.moon, size: 20),
                  ),
                  Gap.w8,
                  Btn('Log in', kind: BtnKind.ghost, onPressed: () => SiteNav.go('login')),
                  Gap.w8,
                  Btn('Get started', trailing: AppIcons.forward, onPressed: () {
                    SiteNav.signupRole = null;
                    SiteNav.go('register');
                  }),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _HeaderLink(this.label, {required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: context.text.titleSmall!.copyWith(fontSize: 14.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? c.ink : c.body)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 3,
              width: active ? 18 : 0,
              decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The public website's top bar on phones: logo, log in, and a menu.
class SiteTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SiteTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        titleSpacing: 16,
        title: InkWell(onTap: () => SiteNav.go('home'), borderRadius: BorderRadius.circular(8), child: const BrandLogo(size: 28)),
        actions: [
          Btn('Log in', kind: BtnKind.soft, size: BtnSize.sm, onPressed: () => SiteNav.go('login')),
          Gap.w8,
          RoundBtn(AppIcons.menu, tooltip: 'Menu', size: 38, onPressed: () => _openMenu(context)),
          Gap.w16,
        ],
      );

  void _openMenu(BuildContext context) => showAppSheet<void>(
        context,
        title: 'Menu',
        builder: (context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MenuGroup(children: [
            for (final (key, label) in _links)
              MenuRow(
                icon: switch (key) { 'technicians' => AppIcons.technicians, 'tools' => AppIcons.tools, 'about' => AppIcons.checklist, _ => AppIcons.home },
                title: label,
                onTap: () {
                  Navigator.of(context).pop();
                  SiteNav.go(key);
                },
              ),
            MenuRow(
              icon: context.isDark ? AppIcons.sun : AppIcons.moon,
              title: context.isDark ? 'Light mode' : 'Dark mode',
              onTap: () {
                _toggleTheme(context);
                Navigator.of(context).pop();
              },
            ),
          ]),
          Gap.h16,
          Btn('Create a free account', size: BtnSize.lg, expand: true, onPressed: () {
            Navigator.of(context).pop();
            SiteNav.signupRole = null;
            SiteNav.go('register');
          }),
        ]),
      );
}

/// Footer shown under every public page.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    final muted = c.onHeroMuted;

    Widget column(String title, List<(String, VoidCallback)> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title.toUpperCase(), style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: muted)),
          Gap.h12,
          for (final (label, onTap) in links)
            Semantics(
              button: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 14, fontWeight: FontWeight.w600, color: c.onHero)),
                ),
              ),
            ),
        ]);

    void signup(String role) {
      SiteNav.signupRole = role;
      SiteNav.go('register');
    }

    final brand = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const BrandLogo(size: 30, onDark: true),
      Gap.h16,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text('Home repairs and tool rentals you can be sure about: verified people, fair prices, payments protected by escrow.',
            style: TextStyle(fontFamily: kBodyFont, fontSize: 14, height: 1.55, fontWeight: FontWeight.w500, color: muted)),
      ),
    ]);
    final columns = [
      column('Marketplace', [
        ('Find technicians', () => SiteNav.go('technicians')),
        ('Rent tools', () => SiteNav.go('tools')),
        ('How it works', () => SiteNav.go('about')),
      ]),
      column('Join', [
        ('Create an account', () => signup('client')),
        ('Become a technician', () => signup('technician')),
        ('List your tools', () => signup('supplier')),
      ]),
      column('SureFix', [
        ('Help & FAQ', () => SiteNav.go('help')),
        ('Terms of use', () => SiteNav.go('terms')),
        ('Privacy', () => SiteNav.go('privacy')),
      ]),
    ];

    return Container(
      width: double.infinity,
      color: context.isDark ? const Color(0xFF090A0C) : c.hero,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1264),
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 32 : 20, wide ? 56 : 36, wide ? 32 : 20, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: brand),
                  for (final col in columns) Expanded(flex: 2, child: col),
                ])
              else ...[
                brand,
                Gap.h32,
                Wrap(spacing: 40, runSpacing: 28, children: columns),
              ],
              SizedBox(height: wide ? 48 : 32),
              Divider(color: c.heroLine),
              Gap.h16,
              Text('© ${DateTime.now().year} SureFix. A final-year project — payments run in a sandbox, no real money moves.',
                  style: TextStyle(fontFamily: kBodyFont, fontSize: 12.5, fontWeight: FontWeight.w500, color: muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
