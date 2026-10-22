import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/site_nav.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../shared/technicians_list_screen.dart';

/// Website footer (public pages).
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFA6B0C3);
    Widget link(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: onTap,
            child: Text(label, style: const TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        );
    Widget column(String title, List<Widget> links) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            ...links,
          ],
        );
    final signedIn = AuthService.instance.loggedIn;
    return Container(
      color: Brand.navy,
      padding: const EdgeInsets.only(top: 64, bottom: 28),
      child: WebContent(
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [LogoMark(size: 40), SizedBox(width: 10), Wordmark(size: 24, color: Colors.white)]),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 320,
                  child: Text(
                    'The marketplace for home repairs and tool rentals. Verified technicians, AI-ranked quotes, and the tools '
                    'to do it yourself.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in ['Verified pros', 'Transparent quotes', 'Secure chat'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                      child: Text(t, style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ]),
            ),
            Expanded(
              flex: 2,
              child: column('Services', [
                for (final c in Catalog.services.take(5))
                  link(c.label, () => push(navigatorKey.currentContext ?? context, TechniciansListScreen(category: c.key))),
              ]),
            ),
            Expanded(
              flex: 2,
              child: column('Marketplace', [
                link('Find technicians', () => SiteNav.go('technicians')),
                link('Rent tools', () => SiteNav.go('tools')),
                link('How it works', () => SiteNav.go('home', anchor: 'how')),
                link('About SureFix', () => SiteNav.go('about')),
              ]),
            ),
            Expanded(
              flex: 2,
              child: column(signedIn ? 'Account' : 'Join SureFix', [
                if (!signedIn) ...[
                  link('Become a technician', () => openSignup('technician')),
                  link('List your tools', () => openSignup('supplier')),
                  link('Create an account', () => openSignup(null)),
                  link('Log in', () => SiteNav.go('login')),
                ] else
                  link('My dashboard', () => SiteNav.go('home')),
              ]),
            ),
          ]),
          const SizedBox(height: 48),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          Row(children: [
            Text('© ${DateTime.now().year} SureFix. All rights reserved.', style: const TextStyle(color: muted, fontSize: 13)),
            const Spacer(),
            const Text('Made with Flutter, Node.js, MongoDB and FastAPI', style: TextStyle(color: muted, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }
}

/// Opens the sign-up page with a role preselected.
void openSignup(String? role) {
  SiteNav.signupRole = role;
  SiteNav.go('register');
}

/// Vertical technician card for website grids.
class WebTechCard extends StatelessWidget {
  final User tech;
  final VoidCallback? onTap;
  const WebTechCard({super.key, required this.tech, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final skill = tech.skills.isNotEmpty ? Catalog.service(tech.skills.first) : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppAvatar(name: tech.name, url: tech.avatar, size: 60, online: tech.online),
              const Spacer(),
              if (skill != null) Pill(skill.label, color: skill.color, icon: skill.icon),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Flexible(child: Text(tech.name, overflow: TextOverflow.ellipsis, style: context.text.titleMedium)),
              if (tech.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 18)],
            ]),
            const SizedBox(height: 4),
            Text(
              tech.headline.isNotEmpty ? tech.headline : (skill?.label ?? 'Technician'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.35),
            ),
            const Spacer(),
            const Divider(height: 24),
            Row(children: [
              RatingLabel(rating: tech.rating, count: tech.ratingCount),
              const Spacer(),
              if (tech.hourlyRate > 0)
                Text.rich(TextSpan(children: [
                  TextSpan(text: Fmt.money(tech.hourlyRate), style: TextStyle(fontWeight: FontWeight.w800, color: context.colors.primary)),
                  TextSpan(text: ' /hr', style: TextStyle(color: p.muted, fontSize: 12)),
                ])),
            ]),
            if (tech.city.isNotEmpty || tech.jobsCompleted > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (tech.city.isNotEmpty) ...[
                  Icon(Icons.place_outlined, size: 15, color: p.subtle),
                  const SizedBox(width: 3),
                  Text(tech.city, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  const SizedBox(width: 12),
                ],
                if (tech.jobsCompleted > 0) ...[
                  Icon(Icons.task_alt_rounded, size: 15, color: p.subtle),
                  const SizedBox(width: 3),
                  Text('${tech.jobsCompleted} jobs', style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Section heading for website pages: small coloured eyebrow, big title,
/// optional lead paragraph and trailing action.
class SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? lead;
  final Widget? trailing;
  final bool center;
  const SectionTitle({super.key, required this.eyebrow, required this.title, this.lead, this.trailing, this.center = false});

  @override
  Widget build(BuildContext context) {
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = center ? TextAlign.center : TextAlign.start;
    final block = Column(crossAxisAlignment: align, children: [
      Text(eyebrow.toUpperCase(),
          style: const TextStyle(color: Brand.accent, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.4)),
      const SizedBox(height: 10),
      Text(title, textAlign: textAlign, style: context.text.headlineMedium?.copyWith(fontSize: 34, height: 1.15)),
      if (lead != null) ...[
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(lead!, textAlign: textAlign, style: context.text.bodyLarge?.copyWith(color: context.palette.muted, fontSize: 17)),
        ),
      ],
    ]);
    if (trailing == null) return block;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: block), trailing!]);
  }
}

/// Grid that lays out [children] in [columns] equal columns, rows sized to
/// the tallest item (unlike GridView, no fixed aspect ratio).
class ColumnsGrid extends StatelessWidget {
  final int columns;
  final double spacing;
  final List<Widget> children;
  final double? rowHeight;
  const ColumnsGrid({super.key, required this.columns, required this.children, this.spacing = 20, this.rowHeight});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(SizedBox(width: spacing));
        final idx = i + c;
        cells.add(Expanded(child: idx < children.length ? children[idx] : const SizedBox.shrink()));
      }
      final row = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells);
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(rowHeight != null ? SizedBox(height: rowHeight, child: row) : IntrinsicHeight(child: row));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Card-styled filter sidebar for website list pages.
class FilterPanel extends StatelessWidget {
  final List<Widget> children;
  const FilterPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

class FilterLabel extends StatelessWidget {
  final String text;
  const FilterLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: context.palette.subtle, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );
}

/// One selectable row in a filter list (e.g. a category).
class FilterOption extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  const FilterOption({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: color ?? context.palette.muted), const SizedBox(width: 10)],
            Expanded(
              child:
                  Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? primary : null)),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: primary),
          ]),
        ),
      ),
    );
  }
}

/// Toggle row for boolean filters.
class FilterSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const FilterSwitch({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: value,
        onChanged: onChanged,
      );
}

/// Gradient welcome banner at the top of website dashboards.
class DashboardBanner extends StatelessWidget {
  final Widget child;
  const DashboardBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(24)),
        child: child,
      );
}

/// Titled card used to group dashboard content on the website.
class PanelCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final EdgeInsets padding;
  const PanelCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 6),
            child: Row(children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ]),
          ),
          Padding(padding: padding, child: child),
        ]),
      );
}
