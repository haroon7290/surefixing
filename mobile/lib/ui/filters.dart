import 'package:flutter/material.dart';

import '../core/location.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import 'buttons.dart';
import 'cards.dart';
import 'icons.dart';
import 'page.dart';
import 'states.dart';

/// A searchable, filterable list of results (technicians, tools, jobs).
///
/// Wide windows: the filters sit in a column on the left of the results and
/// apply at once; the page scrolls as one. Phones: the search box, then a
/// row of quick controls (location, "Filters", sort), then the results.
class FilterLayout<T> extends StatelessWidget {
  final Widget search;
  final Widget panel;
  final List<Widget> phoneBar;
  final Future<T> Function() load;
  final Object? token;
  final Set<String> events;
  final GlobalKey<AsyncViewState<T>>? viewKey;
  final List<Widget> Function(BuildContext context, T data) results;

  const FilterLayout({
    super.key,
    required this.search,
    required this.panel,
    required this.phoneBar,
    required this.load,
    required this.results,
    this.token,
    this.events = const {},
    this.viewKey,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return PageList(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 276, child: panel),
          Gap.w24,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              search,
              Gap.h16,
              AsyncView<T>(
                key: viewKey,
                token: token,
                load: load,
                events: events,
                loading: const SkeletonList(padding: EdgeInsets.zero, count: 3),
                builder: (context, data) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: results(context, data)),
              ),
            ]),
          ),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PagePad(child: search),
      PagePad(
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: phoneBar.length,
            separatorBuilder: (_, __) => Gap.w8,
            itemBuilder: (_, i) => phoneBar[i],
          ),
        ),
      ),
      Expanded(
        child: AsyncView<T>(
          key: viewKey,
          token: token,
          load: load,
          events: events,
          builder: (context, data) => PageList(
            onRefresh: viewKey == null ? null : () => viewKey!.currentState!.reload(),
            children: results(context, data),
          ),
        ),
      ),
    ]);
  }
}

/// The filter column on wide windows.
class FilterPanel extends StatelessWidget {
  final List<Widget> children;
  final int active;
  final VoidCallback? onReset;
  const FilterPanel({super.key, required this.children, this.active = 0, this.onReset});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(AppIcons.filter, size: 18, color: c.ink),
          Gap.w8,
          Expanded(child: Text(active > 0 ? 'Filters · $active' : 'Filters', style: context.text.titleMedium)),
          if (active > 0 && onReset != null) TextButton(onPressed: onReset, child: const Text('Reset')),
        ]),
        for (final child in children) ...[Gap.h12, Divider(height: 1, color: c.line), Gap.h16, child],
      ]),
    );
  }
}

/// One group of controls in a filter panel or sheet.
class FilterGroup extends StatelessWidget {
  final String title;
  final Widget child;
  final String? hint;
  const FilterGroup(this.title, {super.key, required this.child, this.hint});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title.toUpperCase(), style: context.text.labelSmall!.copyWith(letterSpacing: 0.8, color: context.colors.muted, fontWeight: FontWeight.w800)),
        if (hint != null) ...[Gap.h4, Text(hint!, style: context.text.bodySmall)],
        Gap.h12,
        child,
      ]);
}

/// A labelled on/off row inside a filter group.
class FilterToggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const FilterToggle({super.key, required this.label, required this.value, required this.onChanged, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(R.sm),
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: enabled ? c.ink : c.muted), Gap.w12],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: context.text.titleSmall!.copyWith(fontSize: 14, color: enabled ? c.ink : c.muted)),
                if (subtitle != null) ...[Gap.h2, Text(subtitle!, style: context.text.bodySmall)],
              ]),
            ),
            Gap.w8,
            Switch(value: value && enabled, onChanged: onChanged),
          ]),
        ),
      ),
    );
  }
}

/// A capsule button for the phone filter row: "Filters · 2", "Nearest ▾".
class BarButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailing;
  final bool on;
  final VoidCallback? onTap;
  final int badge;
  const BarButton(this.label, {super.key, this.icon, this.trailing, this.on = false, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = on ? c.canvas : c.ink;
    return Semantics(
      button: true,
      child: Material(
        color: on ? c.ink : c.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? c.ink : c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), Gap.w6],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, fontSize: 13.5, fontWeight: FontWeight.w700, color: fg, height: 1.2)),
              ),
              if (badge > 0) ...[
                Gap.w6,
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(99)),
                  child: Text('$badge', textAlign: TextAlign.center, style: TextStyle(fontFamily: kBodyFont, fontSize: 11.5, fontWeight: FontWeight.w800, color: c.onBrand)),
                ),
              ],
              if (trailing != null) ...[Gap.w6, Icon(trailing, size: 12, color: fg)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Sort choice: a capsule that opens a menu.
class SortMenu<T> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  const SortMenu({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: 'Sort',
        initialValue: value,
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [for (final e in options.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
        child: IgnorePointer(child: BarButton(options[value] ?? '', icon: AppIcons.sort, trailing: AppIcons.chevronDown, onTap: () {})),
      );
}

/// The line above the results: "12 technicians near DHA Phase 5" and,
/// on wide windows, the sort menu.
class ResultsHeader extends StatelessWidget {
  final String text;
  final Widget? sort;
  const ResultsHeader(this.text, {super.key, this.sort});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text(text, style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w600))),
          if (sort != null && context.isWide) sort!,
        ]),
      );
}

/// Opens a filter sheet that edits a copy of [initial]; returns the new
/// value when the user taps "Show results", null when dismissed.
Future<T?> showFilterSheet<T>(
  BuildContext context, {
  required T initial,
  required T cleared,
  required List<Widget> Function(BuildContext context, T value, ValueChanged<T> set) groups,
}) {
  var value = initial;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Rebuilds when the search place changes from inside the sheet.
    builder: (context) => ListenableBuilder(
      listenable: Locations.instance,
      builder: (context, _) => StatefulBuilder(builder: (context, setSheet) {
      final c = context.colors;
      void set(T v) => setSheet(() => value = v);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(children: [
              Expanded(child: Text('Filters', style: context.text.headlineSmall)),
              TextButton(onPressed: () => set(cleared), child: const Text('Reset')),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: Icon(AppIcons.close, size: 18, color: c.body)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, g) in groups(context, value, set).indexed) ...[
                  if (i > 0) ...[Gap.h12, Divider(height: 1, color: c.line), Gap.h16],
                  g,
                ],
              ]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Btn('Show results', kind: BtnKind.dark, expand: true, onPressed: () => Navigator.of(context).pop(value)),
            ),
          ),
        ]),
      );
    }),
    ),
  );
}
