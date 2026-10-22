import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import 'site_header.dart';

/// Wraps the whole app (MaterialApp.builder). On wide windows it puts the
/// site header above the navigator, so every page — tabs, pushed screens,
/// dialogs — shows under one persistent website header. On phones it adds
/// nothing.
///
/// The header lives above the navigator, so it gets its own Overlay for
/// tooltips and dropdown menus. The navigator keeps its place in the tree
/// when the window crosses the breakpoint, so no state is lost on resize.
class WebFrame extends StatefulWidget {
  final Widget child;
  const WebFrame({super.key, required this.child});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final ValueNotifier<Widget> _child = ValueNotifier(widget.child);

  // The browser focuses the app before the first layout; Flutter then sorts
  // every focusable widget by position, which fails for header buttons not
  // laid out yet. So the header's buttons arrive one frame later (a
  // same-height placeholder keeps the page from jumping).
  final ValueNotifier<bool> _ready = ValueNotifier(false);

  late final OverlayEntry _entry = OverlayEntry(
    maintainState: true,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([_child, _ready]),
      builder: (context, _) {
        final child = _child.value;
        final wide = context.isWide;
        return Column(
          children: [
            if (wide) _ready.value ? const SiteHeader() : const SizedBox(height: SiteHeader.height),
            // Routes paint a modal barrier with BlockSemantics, which would
            // hide the header (painted earlier) from screen readers. A
            // separate semantics container keeps that blocking inside.
            Expanded(child: Semantics(container: true, child: child)),
          ],
        );
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
    return Theme(
      data: context.isWide ? webTheme(base) : base,
      child: Overlay(initialEntries: [_entry]),
    );
  }
}
