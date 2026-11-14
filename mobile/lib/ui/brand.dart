import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The SureFix mark: a hex nut with a tick, on a safety-orange tile.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: const CustomPaint(painter: _MarkPainter()));
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _orange = Color(0xFFFF5A1F);
  static const _ink = Color(0xFF14161B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.27)), Paint()..color = _orange);

    final nut = hexPath(Offset(s / 2, s / 2), s * 0.3);
    canvas.drawPath(nut, Paint()..color = _ink);
    canvas.drawPath(
      nut,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..strokeJoin = StrokeJoin.round,
    );

    final tick = Path()
      ..moveTo(s * 0.365, s * 0.515)
      ..lineTo(s * 0.46, s * 0.61)
      ..lineTo(s * 0.645, s * 0.405);
    canvas.drawPath(
      tick,
      Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.092
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A pointy-top hexagon centred on [c].
Path hexPath(Offset c, double radius) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = (-90 + 60 * i) * math.pi / 180;
    final p = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Mark + wordmark. [onDark] is for dark surfaces such as the sidebar.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool onDark;
  final bool markOnly;
  const BrandLogo({super.key, this.size = 32, this.onDark = false, this.markOnly = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = onDark ? AppColors.light.canvas : c.ink;
    return Semantics(
      label: 'SureFix',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(size: size),
        if (!markOnly) ...[
          SizedBox(width: size * 0.3),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Sure', style: TextStyle(color: ink)),
              TextSpan(text: 'Fix', style: TextStyle(color: c.brand)),
            ]),
            style: TextStyle(fontFamily: kDisplayFont, fontWeight: FontWeight.w800, fontSize: size * 0.7, letterSpacing: -0.8, height: 1),
          ),
        ],
      ]),
    );
  }
}

/// A faint field of hex nuts: the background texture of dark hero cards.
class HexPattern extends StatelessWidget {
  final Color color;
  final double cell;
  const HexPattern({super.key, required this.color, this.cell = 34});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _HexPainter(color, cell), size: Size.infinite));
}

class _HexPainter extends CustomPainter {
  final Color color;
  final double cell;
  const _HexPainter(this.color, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = cell * math.sqrt(3);
    final rowH = cell * 1.5;
    for (var row = -1; row * rowH < size.height + cell; row++) {
      final offset = row.isOdd ? w / 2 : 0.0;
      for (var col = -1; col * w < size.width + w; col++) {
        // Fade the texture out towards the left so text stays readable.
        final x = col * w + offset;
        final t = (x / size.width).clamp(0.0, 1.0);
        paint.color = color.withValues(alpha: color.a * t * t);
        canvas.drawPath(hexPath(Offset(x, row * rowH), cell * 0.92), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) => oldDelegate.color != color || oldDelegate.cell != cell;
}
