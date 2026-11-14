import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'brand.dart';
import 'buttons.dart';
import 'icons.dart';

/// The basic card: a surface with a hairline border.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;
  final double radius;
  final double borderWidth;

  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.border, this.radius = R.lg, this.borderWidth = 1});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: border ?? c.line, width: borderWidth));
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// A dark feature card with the hex-nut texture: the app's loudest surface.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = R.xl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.hero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: c.heroLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          Positioned.fill(child: HexPattern(color: c.onHero.withValues(alpha: 0.07))),
          Padding(padding: padding, child: child),
        ]),
      ),
    );
  }
}

/// Rounded tile holding an icon, tinted by tone or a custom colour.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final Color? color;
  final Color? background;
  final double size;
  final bool round;
  const IconTile(this.icon, {super.key, this.tone = Tone.neutral, this.color, this.background, this.size = 42, this.round = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? (tone == Tone.neutral ? c.ink : c.fg(tone));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? (color != null ? color!.withValues(alpha: 0.14) : c.bg(tone)),
        borderRadius: BorderRadius.circular(round ? size : size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// Heading above a group of content, with an optional "See all" link.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double top;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.top = 28, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (trailing != null) trailing!,
          if (action != null) LinkText(action!, onTap: onAction, trailing: AppIcons.forward, color: context.colors.body),
        ]),
      );
}

/// One headline number.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Tone tone;
  final String? caption;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.tone = Tone.neutral, this.caption, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconTile(icon, tone: tone, size: 34),
          const Spacer(),
          if (onTap != null) Icon(AppIcons.arrowUpRight, size: 14, color: c.muted),
        ]),
        Gap.h12,
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: context.text.headlineMedium, maxLines: 1)),
        Gap.h2,
        Text(label, style: context.text.bodySmall!.copyWith(color: c.body), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (caption != null) ...[Gap.h4, Text(caption!, style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis)],
      ]),
    );
  }
}

/// "Label ........ value" line for summaries and receipts.
class KV extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;
  final IconData? icon;
  const KV(this.label, this.value, {super.key, this.strong = false, this.valueColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 17, color: c.muted)), Gap.w8],
        Text(label, style: strong ? context.text.titleSmall : context.text.bodyMedium),
        Gap.w16,
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: (strong ? context.text.titleMedium : context.text.titleSmall)!.copyWith(color: valueColor ?? c.ink),
          ),
        ),
      ]),
    );
  }
}

/// A tappable row: icon tile, title, subtitle, chevron. Used in menus.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Tone tone;
  final int badge;
  const MenuRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.tone = Tone.neutral, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconTile(icon, tone: tone, size: 40),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: context.text.titleSmall!.copyWith(fontSize: 14.5, color: tone == Tone.danger ? c.danger : c.ink)),
                if (subtitle != null) ...[Gap.h2, Text(subtitle!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)],
              ]),
            ),
            if (badge > 0) ...[CountBadge(badge), Gap.w8],
            trailing ?? (onTap == null ? const SizedBox.shrink() : Icon(AppIcons.chevronRight, size: 14, color: c.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Rows in one card, separated by hairlines.
class MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const MenuGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(indent: 66, color: context.colors.line),
            children[i],
          ],
        ]),
      );
}

/// Inline callout: explains a state or asks for an action.
class Notice extends StatelessWidget {
  final Tone tone;
  final IconData? icon;
  final String? title;
  final String body;
  final Widget? action;
  const Notice(this.body, {super.key, this.tone = Tone.info, this.icon, this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = c.fg(tone);
    final defaultIcon = switch (tone) {
      Tone.success => AppIcons.success,
      Tone.warning => AppIcons.warningFill,
      Tone.danger => AppIcons.warningFill,
      _ => AppIcons.infoFill,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.bg(tone), borderRadius: BorderRadius.circular(R.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? defaultIcon, size: 20, color: fg),
        Gap.w12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (title != null) ...[Text(title!, style: context.text.titleSmall!.copyWith(color: tone == Tone.neutral ? c.ink : fg)), Gap.h2],
            Text(body, style: context.text.bodyMedium!.copyWith(color: tone == Tone.neutral ? c.body : fg, fontSize: 13.5)),
            if (action != null) ...[Gap.h12, action!],
          ]),
        ),
      ]),
    );
  }
}

/// Small "icon + text" fact line used on cards (city, date, price).
class Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const Meta(this.icon, this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.muted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: fg),
      Gap.w4,
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall!.copyWith(color: fg, fontWeight: FontWeight.w600))),
    ]);
  }
}

/// "2.3 km away · DHA Phase 5" — or just the area when the distance is unknown.
class DistanceText extends StatelessWidget {
  final double? km;
  final String place;
  final bool compact;
  const DistanceText({super.key, this.km, this.place = '', this.compact = false});

  static String? describe(double? km, String place, {bool compact = false}) {
    if (km != null) return compact ? distance(km) : (place.isEmpty ? '${distance(km)} away' : '${distance(km)} · $place');
    return place.isEmpty ? null : place;
  }

  @override
  Widget build(BuildContext context) {
    final text = describe(km, place, compact: compact);
    if (text == null) return const SizedBox.shrink();
    final d = km;
    return Meta(d == null ? AppIcons.pin : AppIcons.route, text, color: d != null && d <= 5 ? context.colors.success : null);
  }
}
