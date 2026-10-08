import 'dart:async';

import 'package:flutter/material.dart';

import 'states.dart';

/// Loads a list, then renders loading skeletons, an error with retry, an
/// empty state, or the items with pull-to-refresh. Pass [reloadOn] (e.g. a
/// filtered realtime stream) to refresh automatically; or hold a
/// GlobalKey<AsyncListState> and call `reload()`.
class AsyncList<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget empty;
  final Stream<dynamic>? reloadOn;
  final EdgeInsets padding;
  final double spacing;
  final Widget? header;
  final Widget? footer;

  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.reloadOn,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 96),
    this.spacing = 12,
    this.header,
    this.footer,
  });

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  List<T>? _items;
  Object? _error;
  StreamSubscription? _sub;

  List<T> get items => _items ?? const [];

  @override
  void initState() {
    super.initState();
    reload();
    _sub = widget.reloadOn?.listen((_) => reload());
  }

  @override
  void didUpdateWidget(covariant AsyncList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadOn != widget.reloadOn) {
      _sub?.cancel();
      _sub = widget.reloadOn?.listen((_) => reload());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Replace items locally (e.g. optimistic updates).
  void setItems(List<T> items) => setState(() => _items = items);

  @override
  Widget build(BuildContext context) {
    if (_items == null && _error == null) {
      return SkeletonList(padding: widget.padding.copyWith(bottom: 16));
    }
    if (_items == null && _error != null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorView(
            message: _error.toString(),
            onRetry: () {
              setState(() => _error = null);
              reload();
            }),
      ]);
    }
    final items = _items!;
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: items.length + 2,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 || i == items.length ? 0 : widget.spacing),
        itemBuilder: (context, i) {
          if (i == 0) {
            if (items.isEmpty) {
              return Column(children: [if (widget.header != null) widget.header!, const SizedBox(height: 40), widget.empty]);
            }
            return widget.header ?? const SizedBox.shrink();
          }
          if (i == items.length + 1) return widget.footer ?? const SizedBox.shrink();
          return widget.itemBuilder(context, items[i - 1], i - 1);
        },
      ),
    );
  }
}
