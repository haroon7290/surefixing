import 'package:flutter/material.dart';

import '../core/theme.dart';

/// SureFix logo mark: gradient tile with a wrench + check.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: [Brand.heroStart, Brand.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Brand.primary.withValues(alpha: 0.35), blurRadius: size * 0.35, offset: Offset(0, size * 0.12)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.handyman_rounded, color: Colors.white, size: size * 0.52),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration:
                  BoxDecoration(color: Brand.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: size * 0.03)),
              child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class Wordmark extends StatelessWidget {
  final double size;
  final Color? color;
  const Wordmark({super.key, this.size = 28, this.color});

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.onSurface;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Sure', style: TextStyle(color: base)),
        const TextSpan(text: 'Fix', style: TextStyle(color: Brand.accent)),
      ]),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.6),
    );
  }
}

/// Deep-blue gradient used by hero headers.
const heroGradient = LinearGradient(
  colors: [Brand.navy, Brand.heroStart, Brand.primary],
  stops: [0, 0.55, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
