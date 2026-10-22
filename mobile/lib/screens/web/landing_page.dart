import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/recommendation.dart';
import '../../models/tool.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../services/site_nav.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import '../shared/technician_profile_screen.dart';
import '../shared/technicians_list_screen.dart';
import '../shared/tool_detail_screen.dart';
import 'web_widgets.dart';

/// Public homepage of the SureFix website.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scroll = ScrollController();
  final _anchors = {'services': GlobalKey(), 'how': GlobalKey()};
  Map<String, dynamic>? _stats;
  List<User>? _techs;
  List<Tool>? _tools;

  @override
  void initState() {
    super.initState();
    _load();
    SiteNav.anchor.addListener(_jump);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  @override
  void dispose() {
    SiteNav.anchor.removeListener(_jump);
    _scroll.dispose();
    super.dispose();
  }

  void _jump() {
    final key = _anchors[SiteNav.anchor.value];
    if (key == null) return;
    SiteNav.anchor.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    });
  }

  Future<void> _load() async {
    ApiClient.getMap('/api/meta/stats').then((v) {
      if (mounted) setState(() => _stats = v);
    }).catchError((_) {});
    ApiClient.getList('/api/users/technicians', query: {'sort': 'rating', 'limit': '4'}).then((v) {
      if (mounted) setState(() => _techs = v.map(User.fromJson).toList());
    }).catchError((_) {
      if (mounted) setState(() => _techs = []);
    });
    ApiClient.getList('/api/tools', query: {'sort': 'popular', 'limit': '4', 'available': '1'}).then((v) {
      if (mounted) setState(() => _tools = v.map(Tool.fromJson).toList());
    }).catchError((_) {
      if (mounted) setState(() => _tools = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(topTech: _techs?.isNotEmpty == true ? _techs!.first : null, stats: _stats),
            _StatsBand(stats: _stats),
            _section(KeyedSubtree(key: _anchors['services'], child: const _Services())),
            _section(KeyedSubtree(key: _anchors['how'], child: const _HowItWorks()), tinted: true),
            _section(const _SmartMatchExplainer()),
            _section(_TopTechnicians(techs: _techs), tinted: true),
            _section(_PopularTools(tools: _tools)),
            _section(const _JoinPros(), tinted: true),
            const _FinalCta(),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }

  Widget _section(Widget child, {bool tinted = false}) => Container(
        color: tinted ? (context.isDark ? context.palette.card : const Color(0xFFEEF2FF)) : null,
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: WebContent(child: child),
      );
}

// ------------------------------------------------------------------ hero

class _Hero extends StatefulWidget {
  final User? topTech;
  final Map<String, dynamic>? stats;
  const _Hero({required this.topTech, required this.stats});

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _text = TextEditingController();
  Timer? _debounce;
  Analysis? _analysis;
  bool _analyzing = false;

  static const _suggestions = [
    'Water leaking under the sink',
    'AC not cooling',
    'Install a ceiling fan',
    'Deep clean my flat',
    'Locked out'
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    if (v.trim().length < 4) {
      setState(() => _analysis = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), _analyze);
  }

  Future<void> _analyze() async {
    final text = _text.text.trim();
    if (text.length < 4) return;
    setState(() => _analyzing = true);
    try {
      final res = await ApiClient.post('/api/ai/analyze', {'text': text});
      // Ignore answers for text the visitor has since changed.
      if (!mounted || _text.text.trim() != text || res is! Map) return;
      setState(() => _analysis = Analysis.fromJson(Map<String, dynamic>.from(res)));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _find() {
    final a = _analysis;
    if (a != null && a.isConfident) {
      push(context, TechniciansListScreen(category: a.category));
    } else {
      SiteNav.go('technicians');
    }
  }

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.78);
    return Container(
      decoration: const BoxDecoration(gradient: heroGradient),
      child: Stack(children: [
        Positioned(right: -120, top: -140, child: _blob(420, 0.07)),
        Positioned(left: -80, bottom: -160, child: _blob(360, 0.05)),
        WebContent(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 72, 0, 112),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                flex: 6,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC266), size: 16),
                      SizedBox(width: 8),
                      Text('AI-matched home services', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Home repairs, done right.\n'),
                      TextSpan(text: 'By people you can trust.', style: TextStyle(color: Color(0xFFFFB04D))),
                    ]),
                    style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Describe the problem in your own words. SureFix works out the service you need, ranks verified technicians '
                    'by skill, ratings and response time, and lets you compare quotes before you hire.',
                    style: TextStyle(color: white70, fontSize: 18, height: 1.55),
                  ),
                  const SizedBox(height: 30),
                  _searchBox(context),
                  const SizedBox(height: 14),
                  SizedBox(height: 30, child: _analysisLine()),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in _suggestions)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _text.text = s;
                          _changed(s);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 30),
                  Wrap(spacing: 24, runSpacing: 10, children: [
                    for (final t in const ['Verified technicians', 'AI-ranked quotes', 'Tool rentals by the day'])
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF6CE9A6), size: 20),
                        const SizedBox(width: 8),
                        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                  ]),
                ]),
              ),
              const SizedBox(width: 64),
              Expanded(flex: 5, child: _HeroVisual(tech: widget.topTech, stats: widget.stats)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _blob(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );

  Widget _searchBox(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome_rounded, color: Brand.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _text,
              onChanged: _changed,
              onSubmitted: (_) => _find(),
              style: const TextStyle(color: Color(0xFF101828), fontSize: 16, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'What needs fixing? e.g. "water leaking under the kitchen sink"',
                hintStyle: TextStyle(color: Color(0xFF98A2B3)),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.accent,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            onPressed: _find,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find a technician'),
          ),
        ]),
      );

  Widget _analysisLine() {
    if (_analyzing && _analysis == null) {
      return const Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10),
        Text('Understanding your problem…', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      ]);
    }
    final a = _analysis;
    if (a == null) return const SizedBox.shrink();
    final cat = Catalog.service(a.category);
    final urgency = UrgencyInfo.of(a.urgency);
    return Row(children: [
      const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC266), size: 18),
      const SizedBox(width: 8),
      const Text('Looks like ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      _chip(cat.label, cat.icon),
      const SizedBox(width: 8),
      _chip(urgency.label, urgency.icon),
      const SizedBox(width: 12),
      Text('${(a.confidence * 100).round().clamp(1, 99)}% sure', style: const TextStyle(color: Colors.white60, fontSize: 13)),
    ]);
  }

  Widget _chip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
}

/// Right-hand side of the hero: the real top-rated technician as a
/// "match" card, plus live platform numbers.
class _HeroVisual extends StatelessWidget {
  final User? tech;
  final Map<String, dynamic>? stats;
  const _HeroVisual({required this.tech, required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = tech;
    final skill = t != null && t.skills.isNotEmpty ? Catalog.service(t.skills.first) : null;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: const EdgeInsets.only(top: 24, right: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 20))],
        ),
        child: t == null
            ? const Column(
                children: [SkeletonCard(), SizedBox(height: 12), Skeleton(height: 12), SizedBox(height: 8), Skeleton(height: 12)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.workspace_premium_rounded, color: context.palette.star, size: 20),
                  const SizedBox(width: 6),
                  Text(skill == null ? 'Top-rated technician' : 'Top-rated in ${skill.label}',
                      style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  AppAvatar(name: t.name, url: t.avatar, size: 60, online: t.online),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: context.text.titleMedium)),
                        if (t.isVerified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 18)],
                      ]),
                      if (t.headline.isNotEmpty)
                        Text(t.headline,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.palette.muted, fontSize: 13.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                _reason(
                    context,
                    Icons.star_rounded,
                    context.palette.star,
                    t.ratingCount == 0
                        ? 'New on SureFix'
                        : '${t.rating.toStringAsFixed(1)} average from ${Fmt.plural(t.ratingCount, 'review')}'),
                if (t.jobsCompleted > 0)
                  _reason(context, Icons.task_alt_rounded, context.palette.success, '${Fmt.plural(t.jobsCompleted, 'job')} completed'),
                _reason(context, Icons.bolt_rounded, context.palette.warning, 'Replies in ${Fmt.responseTime(t.avgResponseMinutes)}'),
                if (t.isVerified) _reason(context, Icons.verified_user_rounded, context.palette.info, 'Identity verified by SureFix'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => push(context, TechnicianProfileScreen(technicianId: t.id)),
                    child: const Text('View profile'),
                  ),
                ),
              ]),
      ),
      if (stats != null && (stats!['reviews'] ?? 0) > 0)
        Positioned(
          left: -28,
          bottom: -26,
          child: _floating(
            context,
            icon: Icons.star_rounded,
            color: context.palette.star,
            title: '${stats!['averageRating']} / 5',
            subtitle: 'from ${Fmt.compact(stats!['reviews'])} reviews',
          ),
        ),
      if (stats != null)
        Positioned(
          right: 0,
          top: 0,
          child: _floating(
            context,
            icon: Icons.verified_user_rounded,
            color: context.palette.success,
            title: '${stats!['verifiedTechnicians']} verified',
            subtitle: 'technicians',
          ),
        ),
    ]);
  }

  Widget _reason(BuildContext context, IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _floating(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(subtitle, style: TextStyle(color: context.palette.muted, fontSize: 12)),
          ]),
        ]),
      );
}

// ----------------------------------------------------------------- stats

class _StatsBand extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatsBand({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String v(String key) => s == null ? '—' : Fmt.compact(s[key] ?? 0);
    final items = [
      (v('technicians'), 'Technicians', Icons.engineering_rounded),
      (v('jobsCompleted'), 'Jobs completed', Icons.task_alt_rounded),
      (s == null ? '—' : '${s['averageRating'] ?? 0}', 'Average rating', Icons.star_rounded),
      (v('tools'), 'Tools for rent', Icons.handyman_rounded),
      (v('cities'), s?['cities'] == 1 ? 'City served' : 'Cities served', Icons.location_city_rounded),
    ];
    return Transform.translate(
      offset: const Offset(0, -48),
      child: WebContent(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.palette.border),
            boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Container(width: 1, height: 48, color: context.palette.border),
              Expanded(
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[i].$3, color: context.colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(items[i].$1, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 4),
                  Text(items[i].$2, style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- services

class _Services extends StatelessWidget {
  const _Services();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle(
        eyebrow: 'Services',
        title: 'Help for every corner of your home',
        lead: 'From a dripping tap to a full repaint — pick a service to see the technicians who do it, their ratings and rates.',
      ),
      const SizedBox(height: 36),
      ColumnsGrid(
        columns: 6,
        spacing: 16,
        rowHeight: 150,
        children: [
          for (final c in Catalog.services)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => push(context, TechniciansListScreen(category: c.key)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CategoryIcon(c, size: 54),
                    const SizedBox(height: 12),
                    Text(c.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------- how it works

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.edit_note_rounded,
        'Describe the problem',
        'Type it in your own words and add photos. Our AI detects the service you need and how urgent it is.'
      ),
      (
        Icons.leaderboard_rounded,
        'Compare ranked quotes',
        'Technicians send quotes. SureFix ranks them by skill, rating, reliability, response time and price — and shows you why.'
      ),
      (
        Icons.handshake_rounded,
        'Hire, chat and review',
        'Chat before and after hiring, follow progress live, and rate the work when it\'s done so the next client knows.'
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle(
        eyebrow: 'How it works',
        title: 'From "it\'s broken" to "it\'s fixed" in three steps',
        center: true,
      ),
      const SizedBox(height: 44),
      ColumnsGrid(columns: 3, spacing: 24, children: [
        for (var i = 0; i < steps.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Brand.heroStart, Brand.primary]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(steps[i].$1, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  Text('0${i + 1}',
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: context.colors.primary.withValues(alpha: 0.15))),
                ]),
                const SizedBox(height: 22),
                Text(steps[i].$2, style: context.text.titleLarge),
                const SizedBox(height: 10),
                Text(steps[i].$3, style: TextStyle(color: context.palette.muted, height: 1.6, fontSize: 15)),
              ]),
            ),
          ),
      ]),
    ]);
  }
}

// ----------------------------------------------------- smart match pitch

class _SmartMatchExplainer extends StatelessWidget {
  const _SmartMatchExplainer();

  // Same weights the matching engine uses (backend/src/services/scoring.js).
  static const _factors = [
    ('Skill match', 0.30, Icons.handyman_rounded),
    ('Ratings', 0.22, Icons.star_rounded),
    ('Reliability — jobs finished', 0.13, Icons.task_alt_rounded),
    ('Experience', 0.09, Icons.workspace_premium_rounded),
    ('Response time', 0.08, Icons.bolt_rounded),
    ('Same city', 0.08, Icons.place_rounded),
    ('Available now', 0.05, Icons.event_available_rounded),
    ('Verified identity', 0.05, Icons.verified_user_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        flex: 5,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle(
            eyebrow: 'Smart Match',
            title: 'Recommendations you can actually understand',
            lead: 'Most platforms just sort by stars. SureFix scores every technician on eight factors and tells you the '
                'reasons behind each match — so you know why someone is at the top.',
          ),
          const SizedBox(height: 28),
          for (final t in const [
            'Understands plain-language problems in 12 service categories',
            'Gives urgent jobs more weight on response time',
            'New technicians aren\'t buried — ratings are smoothed until they have reviews',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: p.success, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              ]),
            ),
        ]),
      ),
      const SizedBox(width: 64),
      Expanded(
        flex: 4,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: Brand.primary),
                const SizedBox(width: 10),
                Text('What goes into a match', style: context.text.titleMedium),
              ]),
              const SizedBox(height: 6),
              Text('Share of the score, before urgency adjustments', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 20),
              for (final f in _factors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Icon(f.$3, size: 18, color: p.muted),
                    const SizedBox(width: 10),
                    SizedBox(width: 210, child: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: f.$2 / 0.30, minHeight: 8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text('${(f.$2 * 100).round()}%',
                          textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------ top technicians

class _TopTechnicians extends StatelessWidget {
  final List<User>? techs;
  const _TopTechnicians({required this.techs});

  @override
  Widget build(BuildContext context) {
    final list = techs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        eyebrow: 'Top rated',
        title: 'Technicians clients keep coming back to',
        trailing: TextButton.icon(
          onPressed: () => SiteNav.go('technicians'),
          icon: const Text('All technicians'),
          label: const Icon(Icons.arrow_forward_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 32),
      if (list != null && list.isEmpty)
        const EmptyState(icon: Icons.engineering_outlined, title: 'Technicians are joining soon')
      else
        ColumnsGrid(
          columns: 4,
          rowHeight: 262,
          children: [
            if (list == null)
              for (var i = 0; i < 4; i++) const Skeleton(height: 262, radius: 16)
            else
              for (final t in list) WebTechCard(tech: t, onTap: () => push(context, TechnicianProfileScreen(technicianId: t.id))),
          ],
        ),
    ]);
  }
}

// -------------------------------------------------------------- tools

class _PopularTools extends StatelessWidget {
  final List<Tool>? tools;
  const _PopularTools({required this.tools});

  @override
  Widget build(BuildContext context) {
    final list = tools;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(
        eyebrow: 'Tool rentals',
        title: 'Rent the tool instead of buying it',
        lead: 'Drills, ladders, pressure washers and more from local suppliers — by the day, with pickup or delivery.',
        trailing: TextButton.icon(
          onPressed: () => SiteNav.go('tools'),
          icon: const Text('Browse all tools'),
          label: const Icon(Icons.arrow_forward_rounded, size: 18),
        ),
      ),
      const SizedBox(height: 32),
      if (list != null && list.isEmpty)
        const EmptyState(icon: Icons.handyman_outlined, title: 'Tools are being listed')
      else
        ColumnsGrid(
          columns: 4,
          rowHeight: 290,
          children: [
            if (list == null)
              for (var i = 0; i < 4; i++) const Skeleton(height: 290, radius: 16)
            else
              for (final t in list) ToolCard(tool: t, onTap: () => push(context, ToolDetailScreen(toolId: t.id))),
          ],
        ),
    ]);
  }
}

// ------------------------------------------------------------ join pros

class _JoinPros extends StatelessWidget {
  const _JoinPros();

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: _card(
          context,
          gradient: heroGradient,
          icon: Icons.engineering_rounded,
          title: 'Earn as a technician',
          body: 'Get matched with jobs in your trade, send quotes, and build a reputation with every review.',
          points: const ['Jobs matched to your skills', 'Direct requests from clients', 'Verified badge after ID check'],
          action: 'Join as a technician',
          onTap: () => openSignup('technician'),
        ),
      ),
      const SizedBox(width: 24),
      Expanded(
        child: _card(
          context,
          gradient: const LinearGradient(colors: [Color(0xFFB54708), Brand.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          icon: Icons.storefront_rounded,
          title: 'Rent out your tools',
          body: 'List equipment people only need occasionally and earn from every rental — you approve each request.',
          points: const ['Daily prices and deposits', 'Pickup or delivery', 'Installment plans for buyers'],
          action: 'List your tools',
          onTap: () => openSignup('supplier'),
        ),
      ),
    ]);
  }

  Widget _card(BuildContext context,
          {required Gradient gradient,
          required IconData icon,
          required String title,
          required String body,
          required List<String> points,
          required String action,
          required VoidCallback onTap}) =>
      Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 22),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, height: 1.55)),
          const SizedBox(height: 20),
          for (final pt in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(pt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Brand.navy,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            onPressed: onTap,
            child: Text(action),
          ),
        ]),
      );
}

class _FinalCta extends StatelessWidget {
  const _FinalCta();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 88),
        child: WebContent(
          maxWidth: 760,
          child: Column(children: [
            Text('Ready to get it fixed?', textAlign: TextAlign.center, style: context.text.headlineMedium?.copyWith(fontSize: 38)),
            const SizedBox(height: 14),
            Text(
              'Create a free account to post a job, get AI-ranked quotes and chat with technicians.',
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(color: context.palette.muted, fontSize: 17),
            ),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28)),
                onPressed: () => openSignup('client'),
                child: const Text('Create a free account'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28)),
                onPressed: () => SiteNav.go('technicians'),
                child: const Text('Browse technicians'),
              ),
            ]),
          ]),
        ),
      );
}
