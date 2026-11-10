import 'package:flutter/material.dart';

import '../../kit.dart';
import '../account/report_sheet.dart';
import '../jobs/post_job_screen.dart';
import 'tech_widgets.dart';

class _Data {
  final User tech;
  final List<Review> reviews;
  final RatingSummary summary;
  const _Data(this.tech, this.reviews, this.summary);
}

/// A technician's public profile: who they are, proof of their work, and
/// what past customers said.
class TechnicianProfileScreen extends StatelessWidget {
  final String technicianId;
  const TechnicianProfileScreen({super.key, required this.technicianId});

  Future<_Data> _load() async {
    final results = await Future.wait([
      Api.map('/api/users/$technicianId'),
      Api.list('/api/reviews/technician/$technicianId', query: {'limit': 30}),
      Api.map('/api/reviews/technician/$technicianId/summary'),
    ]);
    return _Data(User.fromJson(results[0] as Json), (results[1] as List<Json>).map(Review.fromJson).toList(), RatingSummary.fromJson(results[2] as Json));
  }

  void _request(BuildContext context, User tech) {
    final session = Session.instance;
    if (!session.loggedIn) {
      toast('Create a free account to request ${tech.firstName}');
      SiteNav.signupRole = 'client';
      SiteNav.go('register');
    } else {
      push(context, PostJobScreen(technician: tech, category: tech.skills.where((s) => serviceCategories.any((c) => c.key == s)).firstOrNull));
    }
  }

  @override
  Widget build(BuildContext context) => AsyncView<_Data>(
        load: _load,
        loading: const AppPage(title: 'Technician', body: SkeletonList()),
        builder: (context, d) {
          final c = context.colors;
          final t = d.tech;
          final me = Session.instance.user;
          final canRequest = t.isTechnician && (me == null || me.isClient);
          final completion = t.completionRate;

          final header = Panel(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(name: t.name, image: t.avatar, size: context.isWide ? 92 : 72, online: t.online),
                Gap.w16,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Flexible(child: Text(t.name, style: context.text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
                      if (t.verified) ...[Gap.w6, const VerifiedTick(size: 22)],
                    ]),
                    if (t.headline.isNotEmpty) ...[Gap.h2, Text(t.headline, style: context.text.bodyLarge!.copyWith(fontSize: 15))],
                    Gap.h8,
                    Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Rating(t.rating, t.ratingCount, size: 14),
                      if (t.city.isNotEmpty) Meta(AppIcons.pin, t.city),
                      if (t.online) Meta(AppIcons.circle, 'Online now', color: c.success) else if (t.lastSeenAt != null) Meta(AppIcons.clock, 'Active ${timeAgo(t.lastSeenAt)}'),
                    ]),
                  ]),
                ),
                if (t.isTechnician) FavoriteButton(type: 'technician', id: t.id),
              ]),
              if (!t.isAvailable && t.isTechnician) ...[Gap.h12, const Notice('Busy right now — you can still send a request and they will reply when free.', tone: Tone.warning)],
              if (t.isTechnician) ...[
                Gap.h16,
                const Divider(),
                Gap.h12,
                Row(children: [
                  Expanded(child: _Stat(count(t.jobsCompleted), 'Jobs done')),
                  Expanded(child: _Stat(completion == null ? '—' : '${(completion * 100).round()}%', 'Completion')),
                  Expanded(child: _Stat(responseTime(t.avgResponseMinutes), 'Replies in')),
                  Expanded(child: _Stat(t.experienceYears > 0 ? '${t.experienceYears} yr' : '—', 'Experience')),
                ]),
              ],
            ]),
          );

          final about = t.bio.isEmpty && t.skills.isEmpty
              ? null
              : Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('About', style: context.text.titleMedium),
                    if (t.bio.isNotEmpty) ...[Gap.h8, Text(t.bio, style: context.text.bodyLarge!.copyWith(fontSize: 15))],
                    if (t.skills.isNotEmpty) ...[
                      Gap.h12,
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final s in t.skills)
                          Pill(skillLabel(s), icon: serviceCategories.any((cat) => cat.key == s) ? serviceCategory(s).icon : null),
                      ]),
                    ],
                  ]),
                );

          final portfolio = t.portfolio.isEmpty
              ? null
              : Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Recent work', style: context.text.titleMedium),
                    Gap.h12,
                    PhotoStrip(t.portfolio, size: context.isWide ? 140 : 110),
                  ]),
                );

          final reviews = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Reviews', style: context.text.titleMedium),
              Gap.h12,
              if (d.summary.count == 0)
                const EmptyState(compact: true, icon: AppIcons.star, title: 'No reviews yet', message: 'Reviews appear after completed jobs.')
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(d.summary.average.toStringAsFixed(1), style: context.text.displayMedium),
                    Stars(d.summary.average, size: 14),
                    Gap.h4,
                    Text(plural(d.summary.count, 'review'), style: context.text.bodySmall),
                  ]),
                  Gap.w24,
                  Expanded(child: RatingBars(d.summary.distribution)),
                ]),
                Gap.h12,
                for (final r in d.reviews) ...[const Divider(), ReviewTile(r)],
              ],
            ]),
          );

          final cta = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (t.hourlyRate > 0) ...[
                Text('Typical rate', style: context.text.bodySmall),
                Text.rich(TextSpan(children: [
                  TextSpan(text: money(t.hourlyRate), style: context.text.headlineMedium),
                  TextSpan(text: ' /hour', style: context.text.bodyMedium),
                ])),
                Gap.h4,
                Text('You agree the final price on each job before any work starts.', style: context.text.bodySmall),
                Gap.h16,
              ],
              if (canRequest) Btn('Request ${t.firstName}', icon: AppIcons.bolt, size: BtnSize.lg, expand: true, onPressed: () => _request(context, t)),
              if (canRequest) ...[
                Gap.h12,
                for (final (icon, text) in const [
                  (AppIcons.note, 'Describe the job and send it only to them'),
                  (AppIcons.tag, 'They reply with a price you can accept or decline'),
                  (AppIcons.shield, 'Pay through escrow, released when you confirm'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [Icon(icon, size: 16, color: c.brandDeep), Gap.w8, Expanded(child: Text(text, style: context.text.bodySmall!.copyWith(color: c.body)))]),
                  ),
              ],
              if (me != null && me.id != t.id && !me.isAdmin) ...[
                Gap.h8,
                Btn('Report this profile', icon: AppIcons.reports, kind: BtnKind.ghost, size: BtnSize.sm, onPressed: () => showReportSheet(context, targetType: 'user', targetId: t.id, label: t.name)),
              ],
              Gap.h4,
              Text('Member since ${shortDate(t.createdAt)}', textAlign: TextAlign.center, style: context.text.bodySmall),
            ]),
          );

          Widget gap(Widget? w) => w == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: w);
          return AppPage(
            title: t.isTechnician ? 'Technician' : 'Supplier',
            bottom: context.isWide || !canRequest ? null : Btn('Request ${t.firstName}', icon: AppIcons.bolt, size: BtnSize.lg, expand: true, onPressed: () => _request(context, t)),
            body: PageList(children: [
              TwoCol(
                main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [gap(header), gap(about), gap(portfolio), if (t.isTechnician) gap(reviews)]),
                side: cta,
              ),
            ]),
          );
        },
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: context.text.titleLarge, maxLines: 1)),
        Gap.h2,
        Text(label, style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]);
}
