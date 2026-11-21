import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
}

/// Theme adjustments for wide windows.
ThemeData wideTheme(ThemeData base) => base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final p in TargetPlatform.values) p: const FadePageTransitionsBuilder(),
      }),
    );

/// Lays children out in equal columns that wrap, as many as fit at
/// [minWidth]. Cards in a row share the height of the tallest; with
/// [itemHeight] every tile gets that fixed height instead.
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
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          if (itemHeight != null) {
            rows.add(SizedBox(height: itemHeight, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
          } else {
            // Every card in a row as tall as the tallest one.
            rows.add(EqualHeightRow(gap: gap, children: [
              for (var j = 0; j < columns; j++) i + j < children.length ? children[i + j] : const SizedBox.shrink(),
            ]));
          }
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      });
}

/// Scrolling for the whole app. A mouse doesn't drag-scroll pages: on the
/// website that made dragging the scrollbar fight the page (the handle ran
/// away from the cursor). Sideways rows opt in with [MouseDrag].
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

/// Lets a mouse drag a sideways row (filters, photos, cards): a mouse can't
/// swipe, and these rows have no scrollbar to grab.
class MouseDrag extends StatelessWidget {
  final Widget child;
  const MouseDrag({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse}, scrollbars: false),
      child: child,
    );
  }
}

/// Equal-width cells side by side, all as tall as the tallest one: each
/// child is measured at its natural height, then laid out again at the
/// row's height (so card backgrounds line up).
class EqualHeightRow extends MultiChildRenderObjectWidget {
  final double gap;
  const EqualHeightRow({super.key, required super.children, this.gap = 16});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderEqualHeightRow(gap);

  @override
  void updateRenderObject(BuildContext context, RenderEqualHeightRow renderObject) => renderObject.gap = gap;
}

class _EqualRowData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualHeightRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _EqualRowData>, RenderBoxContainerDefaultsMixin<RenderBox, _EqualRowData> {
  RenderEqualHeightRow(this._gap);

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualRowData) child.parentData = _EqualRowData();
  }

  double _cellWidth(double width) => childCount == 0 ? 0 : math.max(0, (width - _gap * (childCount - 1)) / childCount);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final cell = _cellWidth(width);
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints(minWidth: cell, maxWidth: cell), parentUsesSize: true);
      height = math.max(height, child.size.height);
      child = childAfter(child);
    }
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: cell, height: height));
      (child.parentData! as _EqualRowData).offset = Offset(x, 0);
      x += cell + _gap;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  double _maxOf(double Function(RenderBox) f) {
    var v = 0.0;
    var child = firstChild;
    while (child != null) {
      v = math.max(v, f(child));
      child = childAfter(child);
    }
    return v;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _maxOf((c) => c.getMinIntrinsicHeight(_cellWidth(width)));

  @override
  double computeMaxIntrinsicHeight(double width) => _maxOf((c) => c.getMaxIntrinsicHeight(_cellWidth(width)));

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
