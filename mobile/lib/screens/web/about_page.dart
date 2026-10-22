import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/brand.dart';
import '../../widgets/pills.dart';
import 'web_widgets.dart';

/// Public "About" page of the website.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Map<String, dynamic>? _ai;

  @override
  void initState() {
    super.initState();
    ApiClient.getMap('/api/ai/status').then((v) {
      if (mounted) setState(() => _ai = v);
    }).catchError((_) {
      if (mounted) setState(() => _ai = {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const audiences = [
      (
        Icons.home_repair_service_rounded,
        'For clients',
        'Describe a problem in plain words, get matched with the right technician, compare ranked quotes and chat before you hire.',
        Color(0xFF2F54EB)
      ),
      (
        Icons.engineering_rounded,
        'For technicians',
        'Find jobs in your trade, receive direct requests, send quotes, and grow a reputation backed by verified reviews.',
        Color(0xFF12B76A)
      ),
      (
        Icons.storefront_rounded,
        'For suppliers',
        'Rent out tools people only need occasionally. Approve each request, track returns, and offer installment plans.',
        Color(0xFFFF8A00)
      ),
    ];
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            decoration: const BoxDecoration(gradient: heroGradient),
            padding: const EdgeInsets.symmetric(vertical: 72),
            child: const WebContent(
              maxWidth: 820,
              child: Column(children: [
                LogoMark(size: 72),
                SizedBox(height: 22),
                Text('About SureFix', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                SizedBox(height: 14),
                Text(
                  'SureFix is a marketplace for home repairs and tool rentals. We connect people who need something fixed '
                  'with technicians they can trust — and with the tools to do small jobs themselves.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.6),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 72),
            child: WebContent(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(eyebrow: 'Who it\'s for', title: 'One platform, three ways to use it', center: true),
                const SizedBox(height: 40),
                ColumnsGrid(columns: 3, spacing: 24, children: [
                  for (final a in audiences)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: a.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                            child: Icon(a.$1, color: a.$4, size: 28),
                          ),
                          const SizedBox(height: 18),
                          Text(a.$2, style: context.text.titleLarge),
                          const SizedBox(height: 10),
                          Text(a.$3, style: TextStyle(color: p.muted, height: 1.6, fontSize: 15)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 72),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('How it\'s built', style: context.text.titleLarge),
                          const SizedBox(height: 10),
                          Text(
                            'A Flutter app (this website is the same app with a desktop layout), a Node.js + Express API with '
                            'MongoDB and Socket.IO for live updates, and a Python FastAPI service for the AI matching.',
                            style: TextStyle(color: p.muted, height: 1.6),
                          ),
                          const SizedBox(height: 18),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final t in const [
                              'Flutter',
                              'Node.js + Express',
                              'MongoDB',
                              'Socket.IO',
                              'JWT auth',
                              'Python FastAPI',
                              'Naive Bayes NLP',
                            ])
                              Pill(t, color: context.colors.primary),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('System status', style: context.text.titleLarge),
                          const SizedBox(height: 18),
                          _status(context, 'API', 'Online', p.success),
                          const Divider(height: 28),
                          _ai == null
                              ? const LinearProgressIndicator()
                              : _status(
                                  context,
                                  'AI matching engine',
                                  _ai!['online'] == true ? 'Online' : 'Built-in fallback',
                                  _ai!['online'] == true ? p.success : p.warning,
                                ),
                          const SizedBox(height: 14),
                          Text(
                            'If the AI service is offline the API ranks technicians with an identical built-in scorer, so '
                            'matching never stops.',
                            style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          const SiteFooter(),
        ]),
      ),
    );
  }

  Widget _status(BuildContext context, String label, String value, Color color) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Pill(value, color: color, icon: Icons.circle),
      ]);
}
