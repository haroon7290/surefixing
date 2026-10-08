import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/settings_service.dart';
import '../widgets/brand.dart';

class _Page {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Page(this.icon, this.color, this.title, this.body);
}

/// First-launch walkthrough (shown once per device).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Page(Icons.engineering_rounded, Color(0xFF2F54EB), 'Trusted pros for every repair',
        'Plumbers, electricians, AC experts and more — ID-verified, rated by real customers, and ready when you need them.'),
    _Page(Icons.auto_awesome_rounded, Color(0xFF7A5AF8), 'Describe it. We match it.',
        'Tell SureFix what\'s wrong in your own words. Our AI understands the problem and ranks the best technicians — and tells you why.'),
    _Page(Icons.handyman_rounded, Color(0xFFFF8A00), 'Rent tools, skip buying',
        'Need a drill for a day or a ladder for the weekend? Rent from local suppliers, or buy on easy installments.'),
  ];

  void _next() {
    if (_page == _pages.length - 1) {
      SettingsService.instance.completeOnboarding();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  const LogoMark(size: 36),
                  const SizedBox(width: 10),
                  const Wordmark(size: 22),
                  const Spacer(),
                  if (!last) TextButton(onPressed: SettingsService.instance.completeOnboarding, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [p.color.withValues(alpha: 0.22), p.color.withValues(alpha: 0.02)]),
                          ),
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(36),
                                gradient: LinearGradient(
                                  colors: [p.color, Color.lerp(p.color, Colors.black, 0.25)!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12))],
                              ),
                              child: Icon(p.icon, size: 60, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title, textAlign: TextAlign.center, style: context.text.headlineMedium),
                        const SizedBox(height: 14),
                        Text(p.body, textAlign: TextAlign.center, style: context.text.bodyLarge?.copyWith(color: context.palette.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? context.colors.primary : context.palette.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _next, child: Text(last ? 'Get started' : 'Next')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
