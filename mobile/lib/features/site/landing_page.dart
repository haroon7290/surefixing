import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../jobs/job_widgets.dart';
import '../technicians/tech_widgets.dart';
import '../tools/tool_widgets.dart';
import 'content.dart';
import 'site_header.dart';

void _signup([String? role]) {
  SiteNav.signupRole = role;
  SiteNav.go('register');
}

/// A full-width band with centred content.
class Band extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? vertical;
  const Band({super.key, required this.child, this.color, this.vertical});

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return Container(
      width: double.infinity,
      color: color,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1264),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20, vertical: vertical ?? (wide ? 56 : 36)), child: child),
        ),
      ),
    );
  }
}

/// Small orange label above a section heading.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(fontFamily: kBodyFont, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: context.colors.brandDeep));
}

class SectionHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? body;
  final Widget? trailing;
  const SectionHead({super.key, required this.eyebrow, required this.title, this.body, this.trailing});

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Eyebrow(eyebrow),
      Gap.h12,
      Text(title, style: wide ? context.text.displayMedium : context.text.displaySmall!.copyWith(fontSize: 30)),
      if (body != null) ...[
        Gap.h12,
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(body!, style: context.text.bodyLarge!.copyWith(fontSize: wide ? 17 : 15.5))),
      ],
    ]);
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 36 : 24),
      child: trailing == null || !wide ? text : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: text), trailing!]),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.canvas,
      child: ListView(padding: EdgeInsets.zero, children: [
        const _Hero(),
        const _StatsBand(),
        const _Services(),
        Band(color: c.surface, child: const _Steps()),
        const Band(child: _Bento()),
        Band(color: c.surface, child: const _LiveTechnicians()),
        const Band(child: _LiveTools()),
        const _Testimonials(),
        const Band(child: _JoinCards()),
        Band(color: c.surface, child: const FaqList(limit: 5, heading: true)),
        const SiteFooter(),
      ]),
    );
  }
}

// ------------------------------------------------------------------ hero

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    final headline = wide ? context.text.displayLarge!.copyWith(fontSize: 68) : context.text.displayMedium!.copyWith(fontSize: 42);

    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Reveal(
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: c.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Pill('New', solid: true),
            Gap.w8,
            Flexible(child: Text('AI matching + escrow-protected payments', style: context.text.labelMedium!.copyWith(color: c.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      SizedBox(height: wide ? 28 : 20),
      Reveal(
        delayMs: 60,
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Something broken?\nConsider it '),
            TextSpan(text: 'fixed.', style: TextStyle(color: c.brand)),
          ]),
          style: headline,
        ),
      ),
      SizedBox(height: wide ? 22 : 16),
      Reveal(
        delayMs: 120,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Tell us what needs fixing. Verified technicians near you send quotes, our AI shows who fits best and why, and your payment stays in escrow until the job is done. Need the tools instead? Rent them by the day.',
            style: context.text.bodyLarge!.copyWith(fontSize: wide ? 18 : 16),
          ),
        ),
      ),
      SizedBox(height: wide ? 30 : 22),
      const Reveal(delayMs: 180, child: _TryBox()),
    ]);

    return Band(
      vertical: wide ? 64 : 28,
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 11, child: copy),
              const SizedBox(width: 56),
              const Expanded(flex: 9, child: Reveal(delayMs: 200, child: _HeroArt())),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [copy, Gap.h32, const _HeroArt()]),
    );
  }
}

/// "Describe your problem" box: runs the real AI analysis for visitors and
/// shows the category, urgency and a price range before they sign up.
class _TryBox extends StatefulWidget {
  const _TryBox();

  @override
  State<_TryBox> createState() => _TryBoxState();
}

class _TryBoxState extends State<_TryBox> {
  final _controller = TextEditingController();
  bool _busy = false;
  Analysis? _result;

  static const _examples = ['My kitchen tap is leaking', 'AC is not cooling', 'Sparks from a wall socket'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze([String? text]) async {
    if (text != null) _controller.text = text;
    final problem = _controller.text.trim();
    if (problem.length < 3) {
      toast('Describe the problem in a few words');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = Analysis.fromJson(await Api.post('/api/ai/analyze', {'text': problem}));
      if (mounted) setState(() => _result = res);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    final result = _result;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: c.ink, width: 1.6),
            boxShadow: [BoxShadow(color: c.brand.withValues(alpha: 0.18), blurRadius: 0, offset: const Offset(6, 6))],
          ),
          child: Row(children: [
            Gap.w8,
            Icon(AppIcons.sparkleFill, size: 20, color: c.brand),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _analyze(),
                style: context.text.bodyLarge!.copyWith(color: c.ink, fontWeight: FontWeight.w600, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'What needs fixing?',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              ),
            ),
            Btn(wide ? 'Get an estimate' : 'Estimate', loading: _busy, onPressed: _analyze, size: wide ? BtnSize.md : BtnSize.md),
          ]),
        ),
        Gap.h12,
        if (result == null)
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Try:', style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w700)),
            for (final e in _examples)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => _analyze(e),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(999)),
                    child: Text(e, style: context.text.labelMedium!.copyWith(color: c.ink)),
                  ),
                ),
              ),
          ])
        else
          Reveal(
            key: ValueKey(result.category + result.urgency),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  IconTile(serviceCategory(result.category).icon, color: serviceCategory(result.category).color),
                  Gap.w12,
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Looks like ${serviceCategory(result.category).label.toLowerCase()}', style: context.text.titleMedium),
                      Gap.h4,
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill(urgencyLabel(result.urgency), tone: urgencyTone(result.urgency)),
                        if (result.confidence > 0) Pill('${(result.confidence * 100).round()}% sure', icon: AppIcons.sparkle),
                      ]),
                    ]),
                  ),
                ]),
                Gap.h12,
                EstimateBox(result.estimate, lead: 'Jobs like this usually cost'),
                Gap.h12,
                Btn('Post this job — it\'s free', trailing: AppIcons.forward, kind: BtnKind.dark, expand: true, onPressed: () => _signup('client')),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Product collage: real components arranged like a screenshot.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const tech = User(id: 'demo', name: 'Ahmad Raza', headline: 'Master plumber · 12 yrs', kycStatus: 'approved', rating: 4.9, ratingCount: 128, jobsCompleted: 214, city: 'Lahore', online: true);
    return HeroCard(
      padding: EdgeInsets.all(context.isWide ? 28 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(AppIcons.sparkleFill, size: 16, color: c.brand),
          Gap.w8,
          Text('BEST MATCH FOR YOUR JOB', style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.onHeroMuted)),
        ]),
        Gap.h12,
        const ExcludeSemantics(
          child: IgnorePointer(
            child: MatchCard(
              TechMatch(
                technician: tech,
                matchPercent: 96,
                reasons: ['Plumbing specialist with 214 completed jobs', 'Rated 4.9 by 128 customers', 'Replies in about 10 minutes'],
                bidId: 'demo',
                amount: 2800,
                etaDays: 0,
                message: 'I can come by this afternoon and replace the washer.',
              ),
            ),
          ),
        ),
        Gap.h12,
        ExcludeSemantics(
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('Fix leaking kitchen tap', style: context.text.titleSmall)),
                const Pill('Rs 2,800 in escrow', tone: Tone.info, icon: AppIcons.lock),
              ]),
              Gap.h16,
              const StageTrack(2),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- stats

class _StatsBand extends StatelessWidget {
  const _StatsBand();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AsyncView<Json>(
      load: () => Api.map('/api/meta/stats'),
      loading: const SizedBox(height: 8),
      builder: (context, s) {
        final items = [
          (count(integer(s['technicians'])), 'technicians', AppIcons.technicians),
          (count(integer(s['jobsCompleted'])), 'jobs completed', AppIcons.success),
          (count(integer(s['tools'])), 'tools to rent', AppIcons.tools),
          (dbl(s['averageRating']) > 0 ? dbl(s['averageRating']).toStringAsFixed(1) : '—', 'average rating', AppIcons.starFill),
        ];
        return Band(
          vertical: 0,
          child: Panel(
            padding: EdgeInsets.symmetric(horizontal: context.isWide ? 32 : 8, vertical: context.isWide ? 28 : 16),
            child: AutoGrid(
              minWidth: 140,
              gap: 8,
              maxColumns: 4,
              children: [
                for (final (value, label, icon) in items)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 26, color: c.brand),
                    Gap.w12,
                    Flexible(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(value, style: context.text.headlineLarge),
                        Text(label, style: context.text.bodySmall!.copyWith(color: c.body), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------- services

class _Services extends StatelessWidget {
  const _Services();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Band(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHead(eyebrow: 'Services', title: 'Whatever broke,\nsomeone here fixes it.'),
        AutoGrid(
          minWidth: context.isWide ? 180 : 150,
          gap: 12,
          children: [
            for (final cat in serviceCategories)
              Panel(
                onTap: () {
                  SiteNav.presetCategory = cat.key;
                  SiteNav.go('technicians');
                },
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  IconTile(cat.icon, color: cat.color, size: 44),
                  Gap.w12,
                  Expanded(child: Text(cat.label, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Icon(AppIcons.arrowUpRight, size: 14, color: c.muted),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- steps

class _Steps extends StatelessWidget {
  const _Steps();

  static const steps = [
    ('01', 'Describe the problem', 'Write it the way you would tell a friend. Our AI works out the trade, how urgent it is, and what it usually costs.', AppIcons.note),
    ('02', 'Compare quotes', 'Verified technicians send prices. Each one gets a match score with plain-language reasons, so choosing is easy.', AppIcons.scales),
    ('03', 'Pay when it is done', 'Your payment waits in escrow while you follow the work live. It is released only when you confirm the job.', AppIcons.shield),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHead(eyebrow: 'How it works', title: 'Three steps.\nNo chasing, no guessing.'),
      AutoGrid(
        minWidth: 280,
        gap: 16,
        maxColumns: 3,
        children: [
          for (final (n, title, body, icon) in steps)
            Panel(
              color: c.canvas,
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(n, style: context.text.displayMedium!.copyWith(color: c.brand)),
                  const Spacer(),
                  IconTile(icon, size: 46),
                ]),
                Gap.h20,
                Text(title, style: context.text.headlineSmall),
                Gap.h8,
                Text(body, style: context.text.bodyMedium!.copyWith(fontSize: 14.5)),
              ]),
            ),
        ],
      ),
    ]);
  }
}

// ----------------------------------------------------------------- bento

class _Bento extends StatelessWidget {
  const _Bento();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;

    Widget tile(IconData icon, String title, String body, {Widget? art}) => Panel(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            IconTile(icon, tone: Tone.brand, size: 44),
            Gap.h16,
            Text(title, style: context.text.titleLarge),
            Gap.h6,
            Text(body, style: context.text.bodyMedium),
            if (art != null) ...[Gap.h16, art],
          ]),
        );

    final escrow = HeroCard(
      padding: const EdgeInsets.all(26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Icon(AppIcons.shieldFill, size: 34, color: c.brand),
        Gap.h20,
        Text('Your money waits\nuntil the job is done.', style: context.text.headlineLarge!.copyWith(color: c.onHero)),
        Gap.h12,
        Text(
          'Pay into the SureFix Wallet when you hire. The technician sees the money is there, but only receives it when you confirm the work. Cancelled before it starts? It comes straight back.',
          style: context.text.bodyLarge!.copyWith(color: c.onHeroMuted, fontSize: 15.5),
        ),
        Gap.h24,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, icon) in const [('Held in escrow', AppIcons.lock), ('Released on your OK', AppIcons.check), ('Refund if cancelled', AppIcons.refresh)])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: c.onHero.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: c.brand),
                Gap.w6,
                Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.onHero)),
              ]),
            ),
        ]),
      ]),
    );

    final tiles = [
      tile(AppIcons.sparkle, 'AI that explains itself', 'Every match shows its score and the reasons behind it: skills, ratings, reliability, distance and price.'),
      tile(AppIcons.verify, 'Verified identities', 'Technicians and suppliers prove who they are with a government ID before they earn the blue seal.'),
      tile(AppIcons.route, 'Live progress', 'Hired, on the way, working, finished. You see each step the moment it happens.'),
      tile(AppIcons.tools, 'Tools by the day', 'Drills, ladders, pressure washers: rent what you need, or buy in monthly installments.'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHead(eyebrow: 'Why SureFix', title: 'Built so both sides\ncan trust the deal.'),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: escrow),
          Gap.w16,
          Expanded(flex: 7, child: AutoGrid(minWidth: 260, gap: 16, maxColumns: 2, children: tiles)),
        ])
      else ...[
        escrow,
        Gap.h16,
        AutoGrid(minWidth: 260, gap: 12, children: tiles),
      ],
    ]);
  }
}

// ------------------------------------------------------------- live data

class _LiveTechnicians extends StatelessWidget {
  const _LiveTechnicians();

  @override
  Widget build(BuildContext context) => AsyncView<List<User>>(
        load: () async => (await Api.list('/api/users/technicians', query: {'sort': 'rating', 'limit': 4})).map(User.fromJson).toList(),
        loading: const SizedBox(height: 8),
        builder: (context, techs) => techs.isEmpty
            ? const SizedBox.shrink()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHead(
                  eyebrow: 'Top rated',
                  title: 'People your neighbours\nalready trust.',
                  trailing: Btn('See all technicians', kind: BtnKind.outline, trailing: AppIcons.forward, onPressed: () => SiteNav.go('technicians')),
                ),
                AutoGrid(minWidth: 280, gap: 16, maxColumns: 4, children: [for (final t in techs) TechCard(t, showFavorite: false, onTap: () => openTechnician(context, t.id))]),
              ]),
      );
}

class _LiveTools extends StatelessWidget {
  const _LiveTools();

  @override
  Widget build(BuildContext context) => AsyncView<List<Tool>>(
        load: () async => (await Api.list('/api/tools', query: {'sort': 'popular', 'limit': 4})).map(Tool.fromJson).toList(),
        loading: const SizedBox(height: 8),
        builder: (context, tools) => tools.isEmpty
            ? const SizedBox.shrink()
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHead(
                  eyebrow: 'Tool rentals',
                  title: 'Need it once?\nDon\'t buy it.',
                  body: 'Rent quality tools from local suppliers by the day, with a refundable deposit. Pickup or delivery.',
                  trailing: Btn('Browse all tools', kind: BtnKind.outline, trailing: AppIcons.forward, onPressed: () => SiteNav.go('tools')),
                ),
                AutoGrid(
                  minWidth: context.isWide ? 240 : 150,
                  gap: context.isWide ? 16 : 12,
                  maxColumns: 4,
                  itemHeight: context.isWide ? 300 : 250,
                  children: [for (final t in tools) ToolCard(t, showFavorite: false, onTap: () => openTool(context, t.id))],
                ),
              ]),
      );
}

class _Testimonials extends StatelessWidget {
  const _Testimonials();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AsyncView<List<Testimonial>>(
      load: () async => (await Api.list('/api/meta/testimonials')).map(Testimonial.fromJson).toList(),
      loading: const SizedBox(height: 8),
      builder: (context, items) => items.isEmpty
          ? const SizedBox.shrink()
          : Band(
              color: c.surface,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHead(eyebrow: 'Reviews', title: 'Real jobs.\nReal customers.'),
                AutoGrid(
                  minWidth: 300,
                  gap: 16,
                  maxColumns: 3,
                  children: [
                    for (final t in items.take(3))
                      Panel(
                        color: c.canvas,
                        padding: const EdgeInsets.all(22),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [Icon(AppIcons.quotes, size: 28, color: c.brand), const Spacer(), Stars(t.rating.toDouble(), size: 15)]),
                          Gap.h16,
                          Text(t.review, style: context.text.bodyLarge!.copyWith(color: c.ink, fontSize: 15.5), maxLines: 6, overflow: TextOverflow.ellipsis),
                          Gap.h20,
                          Row(children: [
                            Avatar(name: t.clientName, size: 38),
                            Gap.w12,
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text([t.clientName, if (t.clientCity.isNotEmpty) t.clientCity].join(', '), style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${serviceCategory(t.category).label} by ${t.technicianName}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                  ],
                ),
              ]),
            ),
    );
  }
}

// ------------------------------------------------------------------ join

class _JoinCards extends StatelessWidget {
  const _JoinCards();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget card({required bool dark, required IconData icon, required String title, required String body, required String cta, required String role}) {
      final fg = dark ? c.onHero : c.onBrand;
      final content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: dark ? c.brand : c.onBrand),
        Gap.h20,
        Text(title, style: context.text.headlineLarge!.copyWith(color: fg)),
        Gap.h8,
        Text(body, style: context.text.bodyLarge!.copyWith(color: dark ? c.onHeroMuted : c.onBrand.withValues(alpha: 0.78), fontSize: 15.5)),
        Gap.h24,
        Btn(cta, kind: dark ? BtnKind.primary : BtnKind.dark, trailing: AppIcons.forward, onPressed: () => _signup(role)),
      ]);
      if (dark) return HeroCard(padding: const EdgeInsets.all(28), child: content);
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(R.xl)),
        child: content,
      );
    }

    return AutoGrid(minWidth: 320, gap: 16, maxColumns: 2, children: [
      card(
        dark: true,
        icon: AppIcons.techniciansFill,
        title: 'Good with your hands?\nGet paid for it.',
        body: 'Quote on jobs near you, build a verified profile with real reviews, and get paid the moment a customer confirms.',
        cta: 'Become a technician',
        role: 'technician',
      ),
      card(
        dark: false,
        icon: AppIcons.toolsFill,
        title: 'Tools gathering dust?\nPut them to work.',
        body: 'List your equipment, approve rental requests, and earn from deposits-protected rentals and monthly installment sales.',
        cta: 'List your tools',
        role: 'supplier',
      ),
    ]);
  }
}

// ------------------------------------------------------------------- FAQ

/// Expandable questions. Used on the landing page and the help screen.
class FaqList extends StatelessWidget {
  final int? limit;
  final bool heading;
  const FaqList({super.key, this.limit, this.heading = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = limit == null ? faqs : faqs.take(limit!).toList();
    final list = Panel(
      padding: EdgeInsets.zero,
      color: heading ? c.canvas : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(color: c.line),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              expandedAlignment: Alignment.centerLeft,
              iconColor: c.ink,
              collapsedIconColor: c.muted,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(items[i].$1, style: context.text.titleMedium),
              children: [Text(items[i].$2, style: context.text.bodyMedium!.copyWith(fontSize: 14.5))],
            ),
          ),
        ],
      ]),
    );
    if (!heading) return list;
    final head = SectionHead(
      eyebrow: 'Questions',
      title: 'Good to know\nbefore you start.',
      body: context.isWide ? 'Still unsure? The help page covers payments, rentals and verification in more detail.' : null,
    );
    if (!context.isWide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, list]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          Btn('Read all answers', kind: BtnKind.outline, trailing: AppIcons.forward, onPressed: () => SiteNav.go('help')),
        ]),
      ),
      const SizedBox(width: 48),
      Expanded(flex: 7, child: list),
    ]);
  }
}
