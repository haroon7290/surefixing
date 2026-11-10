import 'package:flutter/material.dart';

/// Window width at which SureFix switches from the phone layout (floating
/// dock, stacked screens) to the website layout (sidebar or site header,
/// multi-column pages). Applies to any wide window: browser, desktop app or
/// a tablet in landscape.
const double kWideBreakpoint = 1000;

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isWide => screenWidth >= kWideBreakpoint;

  /// Picks a value for the current layout.
  T pick<T>(T narrow, T wide) => isWide ? wide : narrow;
}

/// Fade-only page transition for the website layout: sliding whole pages
/// sideways feels like an app, not a website.
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
}

/// Theme adjustments for wide windows.
ThemeData wideTheme(ThemeData base) => base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final p in TargetPlatform.values) p: const FadePageTransitionsBuilder(),
      }),
    );

/// Lays children out in equal columns that wrap, as many as fit at
/// [minWidth]. With [itemHeight] every tile gets the same height.
class AutoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final double gap;
  final double? itemHeight;
  final int? maxColumns;
  const AutoGrid({super.key, required this.children, this.minWidth = 280, this.gap = 16, this.itemHeight, this.maxColumns});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        var columns = ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(1, maxColumns ?? 12);
        if (columns > children.length && children.isNotEmpty && maxColumns == null) columns = columns.clamp(1, children.length < 2 ? 2 : children.length);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final cells = <Widget>[];
          for (var j = 0; j < columns; j++) {
            if (j > 0) cells.add(SizedBox(width: gap));
            final index = i + j;
            cells.add(Expanded(child: index < children.length ? children[index] : const SizedBox.shrink()));
          }
          final row = Row(crossAxisAlignment: itemHeight == null ? CrossAxisAlignment.start : CrossAxisAlignment.stretch, children: cells);
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(itemHeight == null ? row : SizedBox(height: itemHeight, child: row));
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      });
}
