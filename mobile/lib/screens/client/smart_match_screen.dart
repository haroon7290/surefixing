import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/recommendation.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/match_card.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import '../shared/technician_profile_screen.dart';
import 'post_job_screen.dart';

/// "Describe it, we match it": the AI assistant that turns a free-text
/// problem into a category + urgency and ranks every technician for it,
/// explaining why each one fits.
class SmartMatchScreen extends StatefulWidget {
  final String? initialText;
  const SmartMatchScreen({super.key, this.initialText});

  @override
  State<SmartMatchScreen> createState() => _SmartMatchScreenState();
}

class _SmartMatchScreenState extends State<SmartMatchScreen> {
  late final _text = TextEditingController(text: widget.initialText ?? '');
  late final _city = TextEditingController(text: AuthService.instance.user?.city ?? '');
  final _scroll = ScrollController();
  String? _categoryOverride;
  bool _loading = false;
  String? _error;
  Analysis? _analysis;
  String _category = '';
  String _urgency = 'normal';
  String _engine = '';
  List<TechMatch> _ranked = [];

  @override
  void initState() {
    super.initState();
    if ((widget.initialText ?? '').isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _text.dispose();
    _city.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search({String? category}) async {
    final description = _text.text.trim();
    if (description.length < 3 && category == null) {
      setState(() => _error = 'Tell us a little about the problem first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _categoryOverride = category;
    });
    try {
      final res = await ApiClient.post('/api/ai/recommend', {
        'description': description,
        if (category != null) 'category': category,
        'city': _city.text.trim(),
        'limit': 10,
      });
      final m = Map<String, dynamic>.from(res);
      if (!mounted) return;
      setState(() {
        _analysis = m['analysis'] is Map ? Analysis.fromJson(Map<String, dynamic>.from(m['analysis'])) : null;
        _category = (m['category'] ?? 'general').toString();
        _urgency = (m['urgency'] ?? 'normal').toString();
        _engine = (m['engine'] ?? '').toString();
        _ranked = (m['ranked'] as List? ?? []).whereType<Map>().map((e) => TechMatch.fromJson(Map<String, dynamic>.from(e))).toList();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(260, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _request(TechMatch? m) {
    push(
      context,
      PostJobScreen(
        initialDescription: _text.text.trim(),
        initialCategory: _category,
        initialUrgency: _urgency,
        requestedTechnician: m == null
            ? null
            : UserLite(id: m.technicianId, name: m.name, avatar: m.avatar, rating: m.rating, ratingCount: m.ratingCount, city: m.city),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 22),
          SizedBox(width: 8),
          Text('Smart Match'),
        ]),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What\'s the problem?', style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text('Describe it in your own words — our AI figures out the trade and finds the best people.',
                      style: TextStyle(color: context.palette.muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Water is dripping from the pipe under my kitchen sink and the cabinet is getting wet'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Your city', prefixIcon: Icon(Icons.place_outlined), isDense: true),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: context.palette.danger, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _search(),
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_loading ? 'Finding your best matches…' : 'Find the best technicians'),
                  ),
                ],
              ),
            ),
          ),
          if (_analysis == null && _ranked.isEmpty && !_loading) _howItWorks(context),
          if (_loading && _ranked.isEmpty) ...[
            const SizedBox(height: 16),
            const SkeletonCard(height: 120),
            const SizedBox(height: 12),
            const SkeletonCard(height: 160),
            const SizedBox(height: 12),
            const SkeletonCard(height: 160),
          ],
          if (_ranked.isNotEmpty || _analysis != null) ...[
            const SizedBox(height: 16),
            _analysisCard(context),
            const SizedBox(height: 8),
            SectionHeader(
              _ranked.isEmpty ? 'No technicians yet' : 'Top ${_ranked.length} matches for you',
              padding: const EdgeInsets.fromLTRB(4, 16, 0, 10),
              trailing: _engine.isEmpty
                  ? null
                  : Pill(
                      _engine == 'ai-service' ? 'SureFix AI' : 'Offline engine',
                      color: _engine == 'ai-service' ? const Color(0xFF7A5AF8) : context.palette.subtle,
                      icon: _engine == 'ai-service' ? Icons.memory_rounded : Icons.cloud_off_rounded,
                    ),
            ),
            for (var i = 0; i < _ranked.length; i++) ...[
              MatchCard(
                match: _ranked[i],
                rank: i,
                onTap: () => push(context, TechnicianProfileScreen(technicianId: _ranked[i].technicianId)),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => push(context, TechnicianProfileScreen(technicianId: _ranked[i].technicianId)),
                    child: const Text('Profile'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _ranked[i].isAvailable ? () => _request(_ranked[i]) : null,
                    child: Text(_ranked[i].isAvailable ? 'Request' : 'Unavailable'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Icon(Icons.campaign_rounded, color: context.colors.primary),
                title: const Text('Prefer to compare quotes?', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Post this job to every matching technician and let them bid.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _request(null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _analysisCard(BuildContext context) {
    final cat = Catalog.service(_category);
    final conf = _analysis?.confidence;
    final keys = {_category, ...?_analysis?.alternatives.map((e) => e.key)}.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(cat, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_categoryOverride != null ? 'You chose' : 'Looks like a job for',
                          style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
                      Text(cat.label, style: context.text.titleLarge),
                    ],
                  ),
                ),
                UrgencyPill(_urgency, hideNormal: false),
              ],
            ),
            if (conf != null && _categoryOverride == null) ...[
              const SizedBox(height: 14),
              Row(children: [
                Text('AI confidence', style: TextStyle(color: context.palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${((conf * 100).round().clamp(1, 99))}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: conf,
                  minHeight: 8,
                  color: conf >= 0.6 ? context.palette.success : (conf >= 0.4 ? context.colors.primary : context.palette.warning),
                ),
              ),
            ],
            if ((_analysis?.keywords ?? []).isNotEmpty || (_analysis?.urgencyTerms ?? []).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Picked up on', style: TextStyle(color: context.palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in _analysis!.keywords.take(5)) Pill(k.length <= 3 ? k.toUpperCase() : k, color: context.colors.primary),
                for (final k in _analysis!.urgencyTerms.where((t) => !_analysis!.keywords.contains(t)).take(3))
                  Pill(k, color: UrgencyInfo.of(_urgency).color, icon: Icons.bolt_rounded),
              ]),
            ],
            const SizedBox(height: 12),
            Text('Not quite right? Pick the trade:',
                style: TextStyle(color: context.palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in [
                    ...keys.map(Catalog.service),
                    ...Catalog.services.where((s) => !keys.contains(s.key)),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(c.icon, size: 16, color: c.color),
                        label: Text(c.label),
                        selected: c.key == _category,
                        showCheckmark: false,
                        onSelected: _loading ? null : (_) => _search(category: c.key),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorks(BuildContext context) {
    final steps = [
      (Icons.edit_note_rounded, 'Describe the problem', 'Plain words are fine — "AC blowing warm air".'),
      (Icons.psychology_rounded, 'AI understands it', 'We detect the trade and how urgent it is.'),
      (Icons.leaderboard_rounded, 'Get ranked matches', 'Scored on skills, reviews, reliability, speed and distance — with reasons.'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text('How it works', style: context.text.titleMedium)),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(steps[i].$1, color: context.colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}. ${steps[i].$2}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(steps[i].$3, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
