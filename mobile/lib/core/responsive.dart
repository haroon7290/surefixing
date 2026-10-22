import 'package:flutter/material.dart';

import 'theme.dart';

/// Window width at which SureFix switches from the phone layout (bottom
/// navigation, stacked screens) to the website layout (top header,
/// centred multi-column pages). Applies to any wide window: browser,
/// desktop app or tablet in landscape.
const double kWebBreakpoint = 1000;

extension ResponsiveX on BuildContext {
  bool get isWide => MediaQuery.sizeOf(this).width >= kWebBreakpoint;
}

/// Centres content at a readable width with side gutters (website pages).
class WebContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double gutter;
  const WebContent({super.key, required this.child, this.maxWidth = 1200, this.gutter = 32});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: child),
        ),
      );
}

/// Wraps a pushed screen so that, on wide windows, it sits in a centred
/// column under the site header instead of stretching edge to edge.
class WebPage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const WebPage({super.key, required this.child, this.maxWidth = 1100});

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return child;
    return ColoredBox(
      color: context.palette.background,
      child: WebContent(maxWidth: maxWidth, gutter: 24, child: child),
    );
  }
}

/// Page title block used at the top of website pages.
class WebPageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  const WebPageTitle(this.title, {super.key, this.subtitle, this.trailing, this.padding = const EdgeInsets.fromLTRB(0, 32, 0, 20)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            // Pushed pages have no app bar on the website: offer a way back.
            if (ModalRoute.of(context)?.canPop ?? false) ...[
              IconButton.outlined(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.headlineMedium?.copyWith(fontSize: 30)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: context.text.bodyLarge?.copyWith(color: context.palette.muted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Fade-only page transition: sliding whole pages sideways feels like an
/// app, not a website.
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
}

/// Theme adjustments for the website layout.
ThemeData webTheme(ThemeData base) => base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final p in TargetPlatform.values) p: const FadePageTransitionsBuilder(),
      }),
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 72,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(fontSize: 24),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(constraints: const BoxConstraints(maxWidth: 640)),
    );
