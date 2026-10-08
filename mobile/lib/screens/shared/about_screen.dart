import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../widgets/brand.dart';
import '../../widgets/pills.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, dynamic>? _ai;

  @override
  void initState() {
    super.initState();
    ApiClient.getMap('/api/ai/status').then((v) {
      if (mounted) setState(() => _ai = v);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final online = _ai?['online'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: LogoMark(size: 76)),
          const SizedBox(height: 16),
          const Center(child: Wordmark(size: 30)),
          const SizedBox(height: 6),
          Center(child: Text('Version 2.0.0', style: TextStyle(color: context.palette.muted))),
          const SizedBox(height: 24),
          Text(
            'SureFix is a marketplace for home repairs and tool rentals. Clients find reliable technicians, '
            'compare AI-ranked quotes and chat before hiring; technicians grow their business; and suppliers '
            'rent out equipment people only need occasionally.',
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('System status', style: context.text.titleSmall),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Text('Backend')),
                  Text(ApiConfig.baseUrl, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('AI engine')),
                  if (_ai == null)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Pill(online ? 'Online' : 'Built-in fallback', color: online ? context.palette.success : context.palette.warning),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Built with', style: context.text.titleSmall),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in ['Flutter', 'Node.js + Express', 'MongoDB', 'Socket.IO', 'JWT', 'Python FastAPI', 'Naive Bayes NLP'])
                    Pill(t, color: context.colors.primary),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
