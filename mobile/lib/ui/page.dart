import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import 'buttons.dart';
import 'icons.dart';

/// Set by a host that already provides the top bar (the public website on
/// phones) and/or wants a footer after every page's content.
class PageFrame extends InheritedWidget {
  final bool hideBar;
  final WidgetBuilder? footer;
  const PageFrame({super.key, required super.child, this.hideBar = false, this.footer});

  static PageFrame? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PageFrame>();

  @override
  bool updateShouldNotify(PageFrame oldWidget) => hideBar != oldWidget.hideBar || footer != oldWidget.footer;
}

class _PageWidth extends InheritedWidget {
  final double maxWidth;
  const _PageWidth({required this.maxWidth, required super.child});

  @override
  bool updateShouldNotify(_PageWidth oldWidget) => maxWidth != oldWidget.maxWidth;
}

/// Side gutter that centres content at [maxWidth] inside [available].
double pageGutter(BuildContext context, double available, double maxWidth) => math.max(context.isWide ? 32.0 : 16.0, (available - maxWidth) / 2);

/// The frame of every screen. On phones: an app bar with a back button and
/// the title. On wide windows: a large in-page heading, centred content.
/// Leave [title] out for screens that draw their own header (dashboards).
class AppPage extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget? bottom; // sticky action bar
  final Widget? fab;
  final PreferredSizeWidget? tabs;
  final double maxWidth;
  final Color? background;

  const AppPage({super.key, this.title, this.subtitle, this.actions = const [], required this.body, this.bottom, this.fab, this.tabs, this.maxWidth = 1120, this.background});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final frame = PageFrame.maybeOf(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final block = context.isWide || (frame?.hideBar ?? false);
    final mq = MediaQuery.of(context);
    // Tab screens sit under the floating dock: lift a FAB above it.
    final dockInset = math.max(0.0, mq.padding.bottom - mq.viewPadding.bottom);

    Widget content = _PageWidth(maxWidth: maxWidth, child: body);
    // Screens without an app bar (dashboards) still clear the status bar.
    if (title == null && !block) content = SafeArea(bottom: false, child: content);
    if (block && (title != null || tabs != null)) {
      content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null) _BlockHeader(title: title!, subtitle: subtitle, actions: actions, canPop: canPop, maxWidth: maxWidth),
        if (tabs != null)
          LayoutBuilder(
            builder: (context, box) => Padding(
              padding: EdgeInsets.symmetric(horizontal: pageGutter(context, box.maxWidth, maxWidth)),
              child: tabs!,
            ),
          ),
        Expanded(child: content),
      ]);
    }

    return Scaffold(
      backgroundColor: background ?? c.canvas,
      appBar: block || title == null
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leadingWidth: 64,
              leading: canPop
                  ? Center(child: RoundBtn(AppIcons.back, tooltip: 'Back', size: 40, onPressed: () => Navigator.of(context).maybePop()))
                  : null,
              titleSpacing: canPop ? 4 : 20,
              title: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [...actions, Gap.w12],
              bottom: tabs,
            ),
      body: content,
      floatingActionButton: fab == null ? null : Padding(padding: EdgeInsets.only(bottom: dockInset), child: fab),
      bottomNavigationBar: bottom == null ? null : _BottomBar(maxWidth: maxWidth, child: bottom!),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool canPop;
  final double maxWidth;
  const _BlockHeader({required this.title, this.subtitle, required this.actions, required this.canPop, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return LayoutBuilder(builder: (context, box) {
      final side = pageGutter(context, box.maxWidth, maxWidth);
      return Padding(
        padding: EdgeInsets.fromLTRB(side, wide ? 32 : 16, side, wide ? 20 : 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (canPop) ...[RoundBtn(AppIcons.back, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()), Gap.w16],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: wide ? context.text.headlineLarge : context.text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[Gap.h4, Text(subtitle!, style: context.text.bodyLarge!.copyWith(fontSize: wide ? 16 : 14))],
            ]),
          ),
          for (final a in actions) ...[Gap.w8, a],
        ]),
      );
    });
  }
}

class _BottomBar extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const _BottomBar({required this.child, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, box) {
          final side = pageGutter(context, box.maxWidth, maxWidth);
          return Padding(padding: EdgeInsets.fromLTRB(side, 12, side, 12), child: child);
        }),
      ),
    );
  }
}

/// The scrolling body of a page: centred at the page's width, with room for
/// the dock, pull-to-refresh, and the host's footer (public website).
class PageList extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double? maxWidth;
  final double top;
  final ScrollController? controller;
  const PageList({super.key, required this.children, this.onRefresh, this.maxWidth, this.top = 8, this.controller});

  @override
  Widget build(BuildContext context) {
    final max = maxWidth ?? context.dependOnInheritedWidgetOfExactType<_PageWidth>()?.maxWidth ?? 1120;
    final footer = PageFrame.maybeOf(context)?.footer;
    final bottom = MediaQuery.paddingOf(context).bottom + 28;
    final list = LayoutBuilder(builder: (context, box) {
      final side = pageGutter(context, box.maxWidth, max);
      return CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, top, side, footer == null ? bottom : 48),
            sliver: SliverList.list(children: children),
          ),
          if (footer != null) SliverFillRemaining(hasScrollBody: false, child: Align(alignment: Alignment.bottomCenter, child: footer(context))),
        ],
      );
    });
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: context.colors.brand, backgroundColor: context.colors.surface, child: list);
  }
}

/// Two columns on wide windows (main + side), stacked on phones.
class TwoCol extends StatelessWidget {
  final Widget main;
  final Widget side;
  final double sideWidth;
  final bool sideFirstOnPhone;
  final bool sideOnLeft;
  const TwoCol({super.key, required this.main, required this.side, this.sideWidth = 360, this.sideFirstOnPhone = false, this.sideOnLeft = false});

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: sideFirstOnPhone ? [side, Gap.h16, main] : [main, Gap.h16, side]);
    }
    final column = SizedBox(width: sideWidth, child: side);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: sideOnLeft ? [column, Gap.w24, Expanded(child: main)] : [Expanded(child: main), Gap.w24, column]);
  }
}

/// Gives fixed content above a [PageList] (search boxes, filter pills) the
/// same side gutters as the list.
class PagePad extends StatelessWidget {
  final Widget child;
  final double top;
  final double bottom;
  const PagePad({super.key, required this.child, this.top = 0, this.bottom = 8});

  @override
  Widget build(BuildContext context) {
    final max = context.dependOnInheritedWidgetOfExactType<_PageWidth>()?.maxWidth ?? 1120;
    return LayoutBuilder(
      builder: (context, box) {
        final side = pageGutter(context, box.maxWidth, max);
        return Padding(padding: EdgeInsets.fromLTRB(side, top, side, bottom), child: child);
      },
    );
  }
}
