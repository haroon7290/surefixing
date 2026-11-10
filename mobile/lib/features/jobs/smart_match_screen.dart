import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'job_widgets.dart';
import 'post_job_screen.dart';

/// Smart Match: describe a problem and the AI ranks every technician for
/// it, with a score and reasons for each.
class SmartMatchScreen extends StatefulWidget {
  const SmartMatchScreen({super.key});

  @override
  State<SmartMatchScreen> createState() => _SmartMatchScreenState();
}

class _SmartMatchScreenState extends State<SmartMatchScreen> {
  final _problem = TextEditingController();
  String? _category;
  bool _busy = false;
  Recommendation? _result;

  static const _examples = ['Water is dripping from the ceiling', 'Fan regulator stopped working', 'Need two rooms painted', 'Cockroaches in the kitchen'];

  @override
  void dispose() {
    _problem.dispose();
    super.dispose();
  }

  Future<void> _match([String? example]) async {
    if (example != null) _problem.text = example;
    final text = _problem.text.trim();
    if (text.length < 3 && _category == null) {
      toast('Describe the problem or pick a category');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.post('/api/ai/recommend', {'description': text, if (_category != null) 'category': _category, 'limit': 12});
      if (mounted) setState(() => _result = Recommendation.fromJson(asJson(res)));
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = _result;
    final cat = r == null ? null : serviceCategory(r.category);

    final ask = HeroCard(
      padding: EdgeInsets.all(context.isWide ? 26 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(AppIcons.sparkleFill, size: 18, color: c.brand),
          Gap.w8,
          Text('SMART MATCH', style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.brand)),
        ]),
        Gap.h8,
        Text('Tell us the problem.\nWe rank who fits best.', style: context.text.headlineMedium!.copyWith(color: c.onHero)),
        Gap.h16,
        TextField(
          controller: _problem,
          maxLines: 3,
          minLines: 3,
          maxLength: 3000,
          textCapitalization: TextCapitalization.sentences,
          style: context.text.bodyLarge!.copyWith(color: c.onHero, fontSize: 15.5),
          cursorColor: c.brand,
          decoration: InputDecoration(
            hintText: 'e.g. The AC is running but the room is not getting cold',
            hintStyle: context.text.bodyLarge!.copyWith(color: c.onHeroMuted, fontSize: 15.5),
            counterText: '',
            fillColor: c.onHero.withValues(alpha: 0.07),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: BorderSide(color: c.heroLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: BorderSide(color: c.brand, width: 1.5)),
          ),
        ),
        Gap.h12,
        Btn('Find my match', icon: AppIcons.sparkleFill, size: BtnSize.lg, expand: true, loading: _busy, onPressed: _match),
      ]),
    );

    return AppPage(
      title: 'Smart Match',
      subtitle: 'AI-ranked technicians for your exact problem.',
      body: PageList(children: [
        TwoCol(
          sideWidth: 400,
          sideFirstOnPhone: true,
          sideOnLeft: true,
          side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            ask,
            if (r == null) ...[
              Gap.h16,
              Text('Or try an example', style: context.text.titleSmall),
              Gap.h8,
              Wrap(spacing: 8, runSpacing: 8, children: [for (final e in _examples) Btn(e, kind: BtnKind.outline, size: BtnSize.sm, onPressed: _busy ? null : () => _match(e))]),
            ] else ...[
              Gap.h16,
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('What the AI understood', style: context.text.bodySmall),
                  Gap.h8,
                  Row(children: [
                    IconTile(cat!.icon, color: cat.color),
                    Gap.w12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(cat.label, style: context.text.titleMedium),
                        Gap.h4,
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          Pill(urgencyLabel(r.urgency), tone: urgencyTone(r.urgency)),
                          if ((r.analysis?.confidence ?? 0) > 0) Pill('${((r.analysis?.confidence ?? 0) * 100).round()}% sure', icon: AppIcons.sparkle),
                        ]),
                      ]),
                    ),
                  ]),
                  if (r.analysis?.keywords.isNotEmpty ?? false) ...[
                    Gap.h12,
                    Text('Picked up on: ${r.analysis!.keywords.take(6).join(', ')}', style: context.text.bodySmall),
                  ],
                ]),
              ),
              Gap.h12,
              EstimateBox(r.estimate),
              Gap.h12,
              Btn('Post this as a job instead', icon: AppIcons.add, kind: BtnKind.dark, expand: true,
                  onPressed: () => push(context, PostJobScreen(description: _problem.text.trim(), category: r.category), path: '/post-job')),
            ],
          ]),
          main: r == null
              ? const Panel(
                  child: EmptyState(
                    icon: AppIcons.sparkle,
                    title: 'Your matches appear here',
                    message: 'Each technician gets a score out of 100 with the reasons behind it: skills, ratings, reliability, response time and distance.',
                  ),
                )
              : (r.ranked.isEmpty
                  ? const Panel(child: EmptyState(icon: AppIcons.technicians, title: 'No technicians found', message: 'Try describing the problem differently.'))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Expanded(child: Text('Top ${r.ranked.length} for you', style: context.text.titleLarge)),
                          Pill(r.engine == 'ai-service' ? 'AI service' : 'Built-in engine', icon: AppIcons.sparkleFill, tone: Tone.brand),
                        ]),
                      ),
                      for (final (i, m) in r.ranked.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MatchCard(m, rank: i + 1, onTap: () => openTechnician(context, m.technician.id), actions: [
                            Btn('View profile', kind: BtnKind.outline, expand: true, onPressed: () => openTechnician(context, m.technician.id)),
                            Btn('Request', icon: AppIcons.bolt, expand: true,
                                onPressed: () => push(context, PostJobScreen(technician: m.technician, description: _problem.text.trim(), category: r.category))),
                          ]),
                        ),
                    ])),
        ),
      ]),
    );
  }
}
