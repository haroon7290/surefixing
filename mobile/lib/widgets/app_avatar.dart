import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/api_config.dart';

/// Circle avatar: uploaded photo, or initials on a colour derived from the
/// name. Optional green "online" dot and verified tick.
class AppAvatar extends StatelessWidget {
  final String name;
  final String url;
  final double size;
  final bool online;
  final bool verified;

  const AppAvatar({super.key, required this.name, this.url = '', this.size = 44, this.online = false, this.verified = false});

  static const _colors = [
    Color(0xFF2F54EB),
    Color(0xFF7A5AF8),
    Color(0xFF12B76A),
    Color(0xFFF79009),
    Color(0xFFEE46BC),
    Color(0xFF06AED4),
    Color(0xFFE04F16),
    Color(0xFF4CA30D),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.codeUnits.fold<int>(0, (a, b) => a + b) % _colors.length];
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38),
      ),
    );
    final dot = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: url.isEmpty
                  ? fallback
                  : Image.network(
                      ApiConfig.mediaUrl(url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallback,
                    ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: context.palette.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.palette.card, width: 2),
                ),
              ),
            ),
          if (verified)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                decoration: BoxDecoration(color: context.palette.card, shape: BoxShape.circle),
                child: Icon(Icons.verified_rounded, size: size * 0.34, color: context.palette.info),
              ),
            ),
        ],
      ),
    );
  }
}
