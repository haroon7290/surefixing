import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/realtime.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'buttons.dart';
import 'cards.dart';
import 'icons.dart';

/// Loads something, shows a skeleton while it loads and an error with a
/// retry if it fails, and quietly reloads on the given realtime [events].
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final Set<String> events;
  final Widget? loading;

  /// Change this value to force a reload (e.g. a filter object).
  final Object? token;

  const AsyncView({super.key, required this.load, required this.builder, this.events = const {}, this.loading, this.token});

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  bool _hasData = false; // a successful load may legitimately return null
  Object? _error;
  bool _loaded = false;
  int _request = 0;
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _debounce;

  T? get data => _data;

  @override
  void initState() {
    super.initState();
    reload();
    if (widget.events.isNotEmpty) {
      _sub = Realtime.instance.on(widget.events).listen((_) {
        // Bursts of events (a new message + its notification) reload once.
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), reload);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) reload(showLoading: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  /// Fetches again. The current content stays on screen meanwhile unless
  /// [showLoading] is set.
  Future<void> reload({bool showLoading = false}) async {
    final request = ++_request;
    if (showLoading && mounted) setState(() => _loaded = false);
    try {
      final data = await widget.load();
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _hasData = true;
        _error = null;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return widget.loading ?? const SkeletonList();
    if (!_hasData) return ErrorState(error: _error ?? 'Something went wrong', onRetry: () => reload(showLoading: true));
    return widget.builder(context, _data as T);
  }
}

/// Friendly "nothing here yet" message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 24 : 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: compact ? 56 : 76,
              height: compact ? 56 : 76,
              decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(compact ? 18 : 24)),
              child: Icon(icon, size: compact ? 26 : 34, color: c.body),
            ),
            Gap.h16,
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[Gap.h6, Text(message!, style: context.text.bodyMedium, textAlign: TextAlign.center)],
            if (action != null) ...[Gap.h20, action!],
          ]),
        ),
      ),
    );
  }
}

/// "That didn't work" with a retry.
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final network = error is ApiError && (error as ApiError).isNetwork;
    return EmptyState(
      icon: network ? AppIcons.offline : AppIcons.warning,
      title: network ? "Can't connect" : 'Something went wrong',
      message: errorText(error),
      action: onRetry == null ? null : Btn('Try again', icon: AppIcons.refresh, kind: BtnKind.dark, onPressed: onRetry),
    );
  }
}

/// A pulsing placeholder block.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(widget.radius))),
    );
  }
}

/// Placeholder for a list of cards.
class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsets padding;
  const SkeletonList({super.key, this.count = 4, this.height = 104, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) Gap.h12,
                Panel(
                  child: SizedBox(
                    height: height - 34,
                    child: const Row(children: [
                      Skeleton(width: 52, height: 52, radius: 16),
                      Gap.w12,
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Skeleton(width: 180, height: 14),
                          SizedBox(height: 10),
                          Skeleton(width: 120, height: 12),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
}

/// Thin bar shown while the live connection is down.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Realtime.instance.connected,
        builder: (context, connected, _) {
          final show = !connected && Session.instance.loggedIn;
          final c = context.colors;
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !show
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    color: c.warningSoft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(AppIcons.offline, size: 14, color: c.warning),
                      Gap.w6,
                      Text('Reconnecting — live updates are paused', style: context.text.bodySmall!.copyWith(color: c.warning, fontWeight: FontWeight.w700)),
                    ]),
                  ),
          );
        },
      );
}

/// Fades and lifts its child in once, optionally after a short delay.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delayMs <= 0) {
      _controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve), child: widget.child),
    );
  }
}
