import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../client/post_job_screen.dart';
import 'report_sheet.dart';

/// Public technician profile: stats, about, skills, rating breakdown and
/// reviews, with "Request service" for clients.
class TechnicianProfileScreen extends StatefulWidget {
  final String technicianId;
  const TechnicianProfileScreen({super.key, required this.technicianId});

  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  User? _tech;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _summary = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getMap('/api/users/${widget.technicianId}'),
        ApiClient.getList('/api/reviews/technician/${widget.technicianId}'),
        ApiClient.getMap('/api/reviews/technician/${widget.technicianId}/summary'),
      ]);
      if (!mounted) return;
      setState(() {
        _tech = User.fromJson(results[0] as Map<String, dynamic>);
        _reviews = results[1] as List<Map<String, dynamic>>;
        _summary = results[2] as Map<String, dynamic>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tech;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList(count: 3),
      );
    }
    final me = AuthService.instance.user!;
    final canRequest = me.isClient && t.id != me.id;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 250,
              foregroundColor: Colors.white,
              backgroundColor: Brand.heroStart,
              actions: [
                if (t.id != me.id)
                  IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: () => showReportSheet(context, targetType: 'user', targetId: t.id, targetName: t.name),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: heroGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                      child: Column(
                        children: [
                          AppAvatar(name: t.name, url: t.avatar, size: 84, online: t.online),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Flexible(
                              child: Text(t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            ),
                            if (t.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, color: Color(0xFF84CAFF), size: 22),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            [if (t.headline.isNotEmpty) t.headline, if (t.city.isNotEmpty) t.city].join(' · '),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(
                      child: _stat(context, t.ratingCount == 0 ? 'New' : t.rating.toStringAsFixed(1), '${t.ratingCount} reviews',
                          Icons.star_rounded, context.palette.star)),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(context, '${t.jobsCompleted}', 'jobs done', Icons.task_alt_rounded, context.palette.success)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(context, t.jobsAssigned == 0 ? '—' : '${(t.completionRate * 100).round()}%', 'completion',
                        Icons.verified_rounded, context.palette.info),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          _stat(context, Fmt.responseTime(t.avgResponseMinutes), 'response', Icons.bolt_rounded, context.palette.warning)),
                ]),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('About', style: context.text.titleSmall),
                        const Spacer(),
                        t.isAvailable
                            ? Pill('Available', color: context.palette.success, icon: Icons.circle)
                            : Pill('Busy right now', color: context.palette.subtle),
                      ]),
                      const SizedBox(height: 8),
                      Text(t.bio.isEmpty ? '${t.name.split(' ').first} hasn\'t written a bio yet.' : t.bio,
                          style: TextStyle(color: t.bio.isEmpty ? context.palette.muted : null)),
                      const SizedBox(height: 10),
                      if (t.hourlyRate > 0) InfoRow(icon: Icons.payments_outlined, label: 'Hourly rate', value: Fmt.money(t.hourlyRate)),
                      if (t.experienceYears > 0)
                        InfoRow(icon: Icons.workspace_premium_outlined, label: 'Experience', value: Fmt.plural(t.experienceYears, 'year')),
                      if (t.createdAt != null)
                        InfoRow(icon: Icons.calendar_month_outlined, label: 'Member since', value: Fmt.date(t.createdAt)),
                      InfoRow(
                        icon: Icons.shield_outlined,
                        label: 'Identity',
                        value: t.isVerified ? 'Verified' : 'Not verified',
                        valueColor: t.isVerified ? context.palette.success : context.palette.muted,
                      ),
                      if (t.skills.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in t.skills)
                            Builder(builder: (context) {
                              final c = Catalog.services.any((x) => x.key == s) ? Catalog.service(s) : null;
                              return Chip(
                                avatar: c == null ? null : Icon(c.icon, size: 16, color: c.color),
                                label: Text(c?.label ?? Fmt.titleCase(s)),
                              );
                            }),
                        ]),
                      ],
                    ]),
                  ),
                ),
                if ((_summary['count'] ?? 0) > 0) ...[
                  const SectionHeader('Ratings', padding: EdgeInsets.fromLTRB(4, 22, 0, 10)),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Column(children: [
                          Text((_summary['average'] as num).toStringAsFixed(1), style: context.text.displaySmall),
                          RatingStars(value: (_summary['average'] as num).toDouble(), size: 16),
                          const SizedBox(height: 4),
                          Text(Fmt.plural(_summary['count'] as int, 'review'),
                              style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
                        ]),
                        const SizedBox(width: 20),
                        Expanded(
                          child: HBarList(
                            labelWidth: 30,
                            colors: [context.palette.star],
                            data: [for (var s = 5; s >= 1; s--) MapEntry('$s★', ((_summary['distribution'] as Map?)?['$s'] ?? 0) as num)],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
                SectionHeader('Reviews (${_reviews.length})', padding: const EdgeInsets.fromLTRB(4, 22, 0, 10)),
                if (_reviews.isEmpty)
                  const Card(child: EmptyState(compact: true, icon: Icons.rate_review_outlined, title: 'No reviews yet'))
                else
                  for (final r in _reviews) ...[_ReviewTile(review: r), const SizedBox(height: 10)],
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: canRequest
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: t.isAvailable
                      ? () => push(
                            context,
                            PostJobScreen(
                              initialCategory:
                                  t.skills.isNotEmpty && Catalog.services.any((c) => c.key == t.skills.first) ? t.skills.first : null,
                              requestedTechnician: UserLite(
                                  id: t.id, name: t.name, avatar: t.avatar, rating: t.rating, ratingCount: t.ratingCount, city: t.city),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(t.isAvailable ? 'Request ${t.firstName}' : '${t.firstName} is not taking jobs right now'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(label, style: TextStyle(fontSize: 11, color: context.palette.muted)),
          ]),
        ),
      );
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final text = (review['review'] ?? '').toString();
    final date = DateTime.tryParse('${review['date']}');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AppAvatar(name: (review['clientName'] ?? 'Client').toString(), url: (review['clientAvatar'] ?? '').toString(), size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((review['clientName'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([review['jobTitle'] ?? '', Fmt.date(date)].where((s) => '$s'.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 12, color: context.palette.muted)),
              ]),
            ),
            RatingStars(value: ((review['rating'] ?? 0) as num).toDouble(), size: 15),
          ]),
          if (text.isNotEmpty) ...[const SizedBox(height: 10), Text(text)],
        ]),
      ),
    );
  }
}
