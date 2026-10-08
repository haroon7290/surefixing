import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Read-only star row supporting half stars.
class RatingStars extends StatelessWidget {
  final double value;
  final double size;
  const RatingStars({super.key, required this.value, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final color = context.palette.star;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = value - i;
        final icon = v >= 0.75 ? Icons.star_rounded : (v >= 0.25 ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: size, color: v >= 0.25 ? color : context.palette.subtle.withValues(alpha: 0.6));
      }),
    );
  }
}

/// Compact "★ 4.8 (21)" label.
class RatingLabel extends StatelessWidget {
  final double rating;
  final int count;
  final double size;
  const RatingLabel({super.key, required this.rating, required this.count, this.size = 13});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text('New', style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: context.palette.info));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: context.palette.star),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size, fontWeight: FontWeight.w700)),
        Text(' ($count)', style: TextStyle(fontSize: size, color: context.palette.muted)),
      ],
    );
  }
}

class RatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const RatingInput({super.key, required this.value, required this.onChanged, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = i + 1;
        return IconButton(
          tooltip: '$v star${v == 1 ? '' : 's'}',
          iconSize: size,
          padding: const EdgeInsets.all(2),
          onPressed: () => onChanged(v),
          icon: Icon(
            v <= value ? Icons.star_rounded : Icons.star_outline_rounded,
            color: v <= value ? context.palette.star : context.palette.subtle,
          ),
        );
      }),
    );
  }
}
