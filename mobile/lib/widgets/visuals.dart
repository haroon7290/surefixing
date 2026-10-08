import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Circular "92% match" gauge.
class MatchRing extends StatelessWidget {
  final int percent;
  final double size;
  final String label;
  const MatchRing({super.key, required this.percent, this.size = 56, this.label = 'match'});

  Color _color(BuildContext context) {
    if (percent >= 80) return context.palette.success;
    if (percent >= 60) return context.colors.primary;
    if (percent >= 40) return context.palette.warning;
    return context.palette.subtle;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              color: c,
              backgroundColor: c.withValues(alpha: 0.14),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.26, color: c, height: 1)),
              if (size >= 52)
                Text(label, style: TextStyle(fontSize: size * 0.15, color: context.palette.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

/// KPI tile: icon chip, big value, label.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: c),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + label + value line used in detail screens.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: context.palette.subtle),
            const SizedBox(width: 12),
            // Labels are short, so they keep their natural width; the value
            // takes the rest and wraps if it has to.
            Text(label, style: TextStyle(color: context.palette.muted)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor), textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}

/// Icon with a red count bubble (navigation, app bar).
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final ValueNotifier<int> count;
  const BadgeIcon({super.key, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (_, n, __) => Badge(
          isLabelVisible: n > 0,
          label: Text(n > 99 ? '99+' : '$n'),
          backgroundColor: context.palette.danger,
          child: Icon(icon),
        ),
      );
}

class TimelineEntry {
  final String title;
  final String subtitle;
  final DateTime? at;
  final IconData icon;
  final Color color;
  TimelineEntry({required this.title, required this.subtitle, required this.at, required this.icon, required this.color});
}

/// Vertical activity timeline.
class Timeline extends StatelessWidget {
  final List<TimelineEntry> entries;
  const Timeline({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: entries[i].color.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(entries[i].icon, size: 15, color: entries[i].color),
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                            child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: context.palette.border)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(entries[i].title, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(Fmt.ago(entries[i].at), style: TextStyle(fontSize: 12, color: context.palette.subtle)),
                          ],
                        ),
                        if (entries[i].subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(entries[i].subtitle, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Minimal vertical bar chart (no chart package needed).
class BarChart extends StatelessWidget {
  final List<MapEntry<String, num>> data;
  final Color? color;
  final double height;
  const BarChart({super.key, required this.data, this.color, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    final maxV = data.isEmpty ? 1 : math.max(1, data.map((e) => e.value).reduce(math.max));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${e.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.palette.muted)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: e.value / maxV),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: math.max(4, (height - 44) * v),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                              colors: [c, c.withValues(alpha: 0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.key, style: TextStyle(fontSize: 11, color: context.palette.subtle), maxLines: 1, overflow: TextOverflow.clip),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Labelled horizontal bars (e.g. rating distribution, users by role).
class HBarList extends StatelessWidget {
  final List<MapEntry<String, num>> data;
  final List<Color>? colors;
  final double labelWidth;
  const HBarList({super.key, required this.data, this.colors, this.labelWidth = 92});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<num>(0, (a, e) => a + e.value);
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                    width: labelWidth,
                    child: Text(data[i].key, style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : data[i].value / total,
                      minHeight: 10,
                      color: colors != null ? colors![i % colors!.length] : context.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                    width: 32,
                    child: Text('${data[i].value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
      ],
    );
  }
}
