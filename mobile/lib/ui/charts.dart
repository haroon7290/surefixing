import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Simple bar chart (e.g. the last seven days). Bars share one colour; the
/// tallest is highlighted.
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;
  final String Function(double) format;
  final Color? color;
  const BarChart({super.key, required this.values, required this.labels, required this.format, this.height = 150, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final peak = values.fold<double>(0, math.max);
    final accent = color ?? c.brand;
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Tooltip(
              message: '${labels[i]}: ${format(values[i])}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(values[i] > 0 ? format(values[i]) : '',
                      maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: context.text.bodySmall!.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.body)),
                  Gap.h4,
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: peak <= 0 ? 0.04 : math.max(0.04, values[i] / peak),
                      child: Container(
                        decoration: BoxDecoration(
                          color: values[i] > 0 && values[i] == peak ? accent : (values[i] > 0 ? accent.withValues(alpha: 0.35) : c.sunken),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Gap.h6,
                  Text(labels[i], maxLines: 1, style: context.text.bodySmall!.copyWith(fontSize: 11)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// One slice of a [SegmentBar].
class Segment {
  final String label;
  final double value;
  final Color color;
  const Segment(this.label, this.value, this.color);
}

/// A stacked horizontal bar with a legend: parts of a whole.
class SegmentBar extends StatelessWidget {
  final List<Segment> segments;
  final String Function(double)? format;
  const SegmentBar({super.key, required this.segments, this.format});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = segments.where((s) => s.value > 0).toList();
    final total = shown.fold<double>(0, (a, s) => a + s.value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: total <= 0
              ? Container(color: c.sunken)
              : Row(children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(flex: math.max(1, (shown[i].value / total * 1000).round()), child: Container(color: shown[i].color)),
                  ],
                ]),
        ),
      ),
      Gap.h12,
      Wrap(spacing: 16, runSpacing: 8, children: [
        for (final s in segments)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
            Gap.w6,
            Text(s.label, style: context.text.bodySmall!.copyWith(color: c.body)),
            Gap.w4,
            Text(format?.call(s.value) ?? s.value.round().toString(), style: context.text.bodySmall!.copyWith(color: c.ink, fontWeight: FontWeight.w700)),
          ]),
      ]),
    ]);
  }
}

/// Rounded progress line.
class ProgressLine extends StatelessWidget {
  final double value; // 0–1
  final Color? color;
  final double height;
  const ProgressLine(this.value, {super.key, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Container(color: c.sunken),
          FractionallySizedBox(widthFactor: value.clamp(0, 1).toDouble(), child: Container(color: color ?? c.brand)),
        ]),
      ),
    );
  }
}

/// The AI match score as a ring with the percentage inside.
class MatchRing extends StatelessWidget {
  final int percent;
  final double size;
  const MatchRing(this.percent, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = percent >= 75 ? c.success : (percent >= 50 ? c.brand : c.muted);
    return Semantics(
      label: '$percent percent match',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(percent / 100, color, c.sunken, size * 0.1),
          child: Center(
            child: Text('$percent', style: TextStyle(fontFamily: kDisplayFont, fontSize: size * 0.34, fontWeight: FontWeight.w700, color: c.ink, height: 1, letterSpacing: -0.5)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;
  const _RingPainter(this.value, this.color, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inner, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(inner, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, base..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Star distribution rows (5★ … 1★) for a reviews summary.
class RatingBars extends StatelessWidget {
  final Map<int, int> distribution;
  const RatingBars(this.distribution, {super.key});

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var star = 5; star >= 1; star--)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 14, child: Text('$star', style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w700))),
            Gap.w6,
            Expanded(child: ProgressLine(total == 0 ? 0 : (distribution[star] ?? 0) / total, color: const Color(0xFFF5A623))),
            Gap.w8,
            SizedBox(width: 26, child: Text('${distribution[star] ?? 0}', textAlign: TextAlign.right, style: context.text.bodySmall)),
          ]),
        ),
    ]);
  }
}
