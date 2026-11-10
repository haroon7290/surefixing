import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'icons.dart';

/// Status chip: a soft tinted capsule with a dot or icon.
class Pill extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dot;
  final bool solid;
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon, this.dot = false, this.solid = false});

  /// Convenience for the `(label, tone)` pairs in `catalog.dart`.
  factory Pill.status((String, Tone) status, {Key? key}) => Pill(status.$1, key: key, tone: status.$2, dot: true);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = solid ? c.onBrand : (tone == Tone.neutral ? c.body : c.fg(tone));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: solid ? c.brand : c.bg(tone), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), Gap.w6],
        if (icon != null) ...[Icon(icon, size: 13, color: fg), Gap.w4],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w700, color: fg, height: 1.2)),
        ),
      ]),
    );
  }
}

/// "★ 4.8 (120)". Shows "New" until there are reviews.
class Rating extends StatelessWidget {
  final double value;
  final int count;
  final double size;
  final bool showCount;
  const Rating(this.value, this.count, {super.key, this.size = 13, this.showCount = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(fontFamily: kBodyFont, fontSize: size, fontWeight: FontWeight.w700, color: c.ink, height: 1.2);
    if (count <= 0) return Text('New', style: style.copyWith(color: c.muted));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(AppIcons.starFill, size: size + 1, color: const Color(0xFFF5A623)),
      const SizedBox(width: 3),
      Text(value.toStringAsFixed(1), style: style),
      if (showCount) Text(' (${_short(count)})', style: style.copyWith(color: c.muted, fontWeight: FontWeight.w600)),
    ]);
  }

  static String _short(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

/// A row of five stars: read-only, or tappable when [onChanged] is given.
class Stars extends StatelessWidget {
  final double value;
  final double size;
  final ValueChanged<int>? onChanged;
  const Stars(this.value, {super.key, this.size = 16, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Semantics(
          button: onChanged != null,
          label: onChanged == null ? null : '$i star${i == 1 ? '' : 's'}',
          excludeSemantics: onChanged != null,
          child: GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.all(onChanged == null ? 0.5 : 5),
              child: Icon(value >= i - 0.25 ? AppIcons.starFill : AppIcons.star, size: size, color: value >= i - 0.25 ? const Color(0xFFF5A623) : c.line),
            ),
          ),
        ),
    ]);
  }
}

/// The blue "verified identity" seal.
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Identity verified',
        child: Icon(AppIcons.verified, size: size, color: context.colors.info, semanticLabel: 'Verified'),
      );
}

/// Profile picture, or initials on a colour picked from the name.
class Avatar extends StatelessWidget {
  final String name;
  final String image;
  final double size;
  final bool online;
  final bool square;
  const Avatar({super.key, required this.name, this.image = '', this.size = 44, this.online = false, this.square = false});

  static const _palette = [Color(0xFFFF5A1F), Color(0xFF2E7BE8), Color(0xFF12A679), Color(0xFF7C5CFC), Color(0xFFE5488B), Color(0xFFE5A100), Color(0xFF14A3C7)];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _palette[name.runes.fold<int>(0, (a, b) => a + b) % _palette.length];
    final radius = BorderRadius.circular(square ? size * 0.28 : size);
    final fallback = Container(
      color: color.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(initials(name),
          style: TextStyle(fontFamily: kDisplayFont, fontSize: size * 0.38, fontWeight: FontWeight.w700, color: color, height: 1, letterSpacing: -0.3)),
    );
    final face = ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: size,
        child: image.isEmpty
            ? fallback
            : Image.network(mediaUrl(image), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback, semanticLabel: name),
      ),
    );
    if (!online) return face;
    final dot = (size * 0.26).clamp(9.0, 16.0);
    return Stack(clipBehavior: Clip.none, children: [
      face,
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: c.success, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
        ),
      ),
    ]);
  }
}

/// Avatar + name (+ verified seal) + a line underneath.
class PersonRow extends StatelessWidget {
  final String name;
  final String image;
  final String? subtitle;
  final Widget? below;
  final bool verified;
  final bool online;
  final double size;
  final Widget? trailing;
  final VoidCallback? onTap;
  const PersonRow({super.key, required this.name, this.image = '', this.subtitle, this.below, this.verified = false, this.online = false, this.size = 44, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Avatar(name: name, image: image, size: size, online: online),
      Gap.w12,
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(child: Text(name, style: context.text.titleSmall!.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (verified) ...[Gap.w4, const VerifiedTick(size: 15)],
          ]),
          if (subtitle != null && subtitle!.isNotEmpty) ...[Gap.h2, Text(subtitle!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)],
          if (below != null) ...[Gap.h4, below!],
        ]),
      ),
      if (trailing != null) ...[Gap.w8, trailing!],
    ]);
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(R.sm), child: row);
  }
}
