import 'package:flutter/material.dart';

import '../core/theme.dart';

enum BtnKind { primary, dark, soft, outline, ghost, danger }

enum BtnSize { sm, md, lg }

/// The app's button. `primary` (orange) is the one main action on a screen;
/// `dark` a strong secondary; `soft`/`outline`/`ghost` for everything else.
class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailing;
  final BtnKind kind;
  final BtnSize size;
  final bool loading;
  final bool expand;

  const Btn(this.label,
      {super.key, this.onPressed, this.icon, this.trailing, this.kind = BtnKind.primary, this.size = BtnSize.md, this.loading = false, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (c.brand, c.onBrand, null),
      BtnKind.dark => (c.ink, c.canvas, null),
      BtnKind.soft => (c.sunken, c.ink, null),
      BtnKind.outline => (Colors.transparent, c.ink, c.line),
      BtnKind.ghost => (Colors.transparent, c.ink, null),
      BtnKind.danger => (c.dangerSoft, c.danger, null),
    };
    final (height, pad, font, iconSize, radius) = switch (size) {
      BtnSize.sm => (36.0, 12.0, 13.0, 16.0, R.sm),
      BtnSize.md => (46.0, 18.0, 14.5, 18.0, R.md),
      BtnSize.lg => (54.0, 22.0, 16.0, 20.0, 16.0),
    };
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(dimension: iconSize, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else if (icon != null)
          Icon(icon, size: iconSize, color: fg),
        if (loading || icon != null) SizedBox(width: size == BtnSize.sm ? 6 : 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kBodyFont, fontSize: font, fontWeight: FontWeight.w700, color: fg, height: 1.1, letterSpacing: -0.1),
          ),
        ),
        if (trailing != null) ...[SizedBox(width: size == BtnSize.sm ? 6 : 8), Icon(trailing, size: iconSize, color: fg)],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.45 : 1,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: pad),
              alignment: expand ? Alignment.center : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button on a surface, with an optional unread badge.
class RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final int badge;
  final double size;
  final Color? color;
  final Color? background;
  final bool bordered;

  const RoundBtn(this.icon,
      {super.key, this.onPressed, required this.tooltip, this.badge = 0, this.size = 44, this.color, this.background, this.bordered = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: background ?? c.surface,
          shape: CircleBorder(side: bordered ? BorderSide(color: c.line) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: size, child: Icon(icon, size: size * 0.46, color: color ?? c.ink)),
          ),
        ),
      ),
    );
    if (badge <= 0) return button;
    return Stack(clipBehavior: Clip.none, children: [
      button,
      Positioned(right: -2, top: -2, child: CountBadge(badge)),
    ]);
  }
}

/// Small orange counter (unread messages, pending requests).
class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(9)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(fontFamily: kBodyFont, fontSize: 10.5, fontWeight: FontWeight.w800, color: c.onBrand, height: 1),
      ),
    );
  }
}

/// Inline text link.
class LinkText extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? trailing;
  const LinkText(this.label, {super.key, this.onTap, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: context.text.labelLarge!.copyWith(color: fg, fontSize: 13.5)),
            if (trailing != null) ...[Gap.w4, Icon(trailing, size: 13, color: fg)],
          ]),
        ),
      ),
    );
  }
}
