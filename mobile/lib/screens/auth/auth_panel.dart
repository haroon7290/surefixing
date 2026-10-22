import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/brand.dart';

/// Website layout for the login and sign-up pages: a brand panel on the
/// left, the form on the right.
class AuthSplitLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String subtitle;
  const AuthSplitLayout({
    super.key,
    required this.child,
    this.title = 'Home repairs and tool rentals, sorted.',
    this.subtitle = 'Join thousands of homeowners, technicians and suppliers who get things fixed with SureFix.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: heroGradient),
            child: Stack(children: [
              Positioned(
                right: -90,
                bottom: -90,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(56),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const LogoMark(size: 64),
                      const SizedBox(height: 28),
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8)),
                      const SizedBox(height: 14),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16.5, height: 1.55)),
                      const SizedBox(height: 32),
                      for (final f in const [
                        (Icons.auto_awesome_rounded, 'AI Smart Match', 'Describe the problem — we find the right pro.'),
                        (Icons.verified_user_rounded, 'Verified technicians', 'ID-checked pros with real reviews.'),
                        (Icons.forum_rounded, 'Chat and live updates', 'Talk before you hire, track every step.'),
                        (Icons.handyman_rounded, 'Tool rentals', 'Rent by the day instead of buying.'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration:
                                  BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                              child: Icon(f.$1, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(f.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(f.$3, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13.5)),
                              ]),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          flex: 6,
          child: ColoredBox(
            color: context.palette.background,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
