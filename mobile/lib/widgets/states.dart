import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Friendly empty state with an icon, message and optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 84.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 20 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.primary.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: size * 0.46, color: context.colors.primary),
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(title, style: compact ? context.text.titleSmall : context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: TextStyle(color: context.palette.muted), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        message: message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

/// Pulsing placeholder block used while content loads.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.palette.fill;
    final hi = context.isDark ? const Color(0xFF243055) : const Color(0xFFE7EAF0);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, hi, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton row (avatar + two lines).
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 92});

  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          height: height,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Skeleton(width: 52, height: 52, radius: 14),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 160, height: 14),
                      SizedBox(height: 10),
                      Skeleton(height: 11),
                      SizedBox(height: 8),
                      Skeleton(width: 90, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const SkeletonList({super.key, this.count = 5, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonCard(),
      );
}

/// Section title with optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final Widget? trailing;

  const SectionHeader(this.title,
      {super.key, this.actionLabel, this.onAction, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 24, 12, 10)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.text.titleMedium?.copyWith(fontSize: 17))),
            if (trailing != null) trailing!,
            if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

/// Banner shown when the realtime socket has been disconnected for a few
/// seconds (so it doesn't flash during the initial connect).
class OfflineBanner extends StatefulWidget {
  final ValueNotifier<bool> connected;
  const OfflineBanner({super.key, required this.connected});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.connected.addListener(_update);
    _update();
  }

  @override
  void dispose() {
    widget.connected.removeListener(_update);
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    _timer?.cancel();
    if (widget.connected.value) {
      if (_show && mounted) setState(() => _show = false);
    } else {
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted && !widget.connected.value) setState(() => _show = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: !_show
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                color: context.palette.warning.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: context.palette.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Reconnecting… live updates paused',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.palette.warning)),
                    ),
                  ],
                ),
              ),
      );
}
