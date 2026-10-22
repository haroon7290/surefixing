import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shared/edit_profile_screen.dart';
import '../shared/kyc_screen.dart';
import '../shared/notifications_screen.dart';
import '../shells.dart';
import '../web/web_widgets.dart';
import 'tech_job_detail.dart';

class TechDashboard extends StatefulWidget {
  const TechDashboard({super.key});

  @override
  State<TechDashboard> createState() => _TechDashboardState();
}

class _TechDashboardState extends State<TechDashboard> {
  Map<String, dynamic>? _summary;
  List<Job>? _requests;
  List<Job>? _matching;
  StreamSubscription? _sub;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'job:new', 'job:request', 'job:hired', 'job:status', 'job:rated'}).listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getMap('/api/users/me/summary'),
        ApiClient.getList('/api/jobs', query: {'view': 'requests'}),
        ApiClient.getList('/api/jobs', query: {'matching': '1', 'limit': '5'}),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _requests = (results[1] as List<Map<String, dynamic>>).map(Job.fromJson).toList();
        _matching = (results[2] as List<Map<String, dynamic>>).map(Job.fromJson).toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _summary ??= {};
          _requests ??= [];
          _matching ??= [];
        });
      }
    }
  }

  Future<void> _toggleAvailability(bool v) async {
    setState(() => _toggling = true);
    try {
      await AuthService.instance.updateProfile({'isAvailable': v});
      toast(v ? 'You\'re available for new jobs' : 'You\'re marked as busy', kind: ToastKind.success);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _open(Job j) async {
    await push(context, TechJobDetail(jobId: j.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final me = AuthService.instance.user!;
        final s = _summary;
        final p = context.palette;
        if (context.isWide) return _wide(context, me);
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: const BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          AppAvatar(name: me.name, url: me.avatar, size: 44, verified: me.isVerified),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Hi, ${me.firstName}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                              Text(me.headline.isEmpty ? 'Technician' : me.headline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                            ]),
                          ),
                          IconButton(
                            color: Colors.white,
                            tooltip: 'Notifications',
                            onPressed: () async {
                              await push(context, const NotificationsScreen());
                              BadgeService.instance.refresh();
                            },
                            icon: BadgeIcon(icon: Icons.notifications_none_rounded, count: BadgeService.instance.unreadNotifications),
                          ),
                        ]),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            Icon(me.isAvailable ? Icons.circle : Icons.do_not_disturb_on_rounded,
                                size: 14, color: me.isAvailable ? const Color(0xFF32D583) : Colors.white60),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(me.isAvailable ? 'Available for new jobs' : 'Busy — not taking new jobs',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                            Switch(value: me.isAvailable, onChanged: _toggling ? null : _toggleAvailability),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: [
                      StatTile(
                          icon: Icons.account_balance_wallet_rounded,
                          value: s == null ? '—' : Fmt.compactMoney(s['earnings'] ?? 0),
                          label: 'Earned on SureFix',
                          color: p.success),
                      StatTile(
                          icon: Icons.handyman_rounded,
                          value: '${s?['activeJobs'] ?? '—'}',
                          label: 'Active jobs',
                          color: p.warning,
                          onTap: () => HomeShell.goTo(context, 2)),
                      StatTile(
                          icon: Icons.request_quote_rounded,
                          value: '${s?['pendingBids'] ?? '—'}',
                          label: 'Quotes awaiting reply',
                          color: context.colors.primary,
                          onTap: () => HomeShell.goTo(context, 2)),
                      StatTile(
                        icon: Icons.star_rounded,
                        value: me.ratingCount == 0 ? 'New' : me.rating.toStringAsFixed(1),
                        label: '${Fmt.plural(me.ratingCount, 'review')} · ${s?['completedJobs'] ?? me.jobsCompleted} done',
                        color: p.star,
                      ),
                    ],
                  ),
                ),
                if (!me.isVerified)
                  _prompt(
                    context,
                    icon: Icons.verified_user_rounded,
                    color: p.info,
                    title: me.kycStatus == 'pending' ? 'Verification in review' : 'Get verified',
                    body: me.kycStatus == 'pending'
                        ? 'We\'ll notify you as soon as it\'s approved.'
                        : 'Verified technicians get a badge and rank higher in Smart Match.',
                    onTap: () => push(context, const KycScreen()),
                  ),
                if (me.profileCompleteness < 1)
                  _prompt(
                    context,
                    icon: Icons.auto_graph_rounded,
                    color: Brand.accent,
                    title: 'Profile ${(me.profileCompleteness * 100).round()}% complete',
                    body: 'Add ${me.missingProfileItems.take(2).join(' and ')} to appear in more AI matches.',
                    onTap: () => push(context, const EditProfileScreen()),
                  ),
                SectionHeader('Direct requests${_requests == null || _requests!.isEmpty ? '' : ' (${_requests!.length})'}'),
                if (_requests == null)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonCard())
                else if (_requests!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                        child: EmptyState(
                            compact: true,
                            icon: Icons.person_pin_outlined,
                            title: 'No requests right now',
                            message: 'Clients who pick you from Smart Match will appear here.')),
                  )
                else
                  for (final j in _requests!)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: JobCard(job: j, viewerId: me.id, showClient: true, onTap: () => _open(j))),
                SectionHeader('Jobs matching your skills', actionLabel: 'Find work', onAction: () => HomeShell.goTo(context, 1)),
                if (_matching == null)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonCard())
                else if (_matching!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: EmptyState(
                        compact: true,
                        icon: Icons.search_off_rounded,
                        title: me.skills.isEmpty ? 'Add your skills' : 'No open jobs in your trades',
                        message: me.skills.isEmpty
                            ? 'Tell us what you do to see matching jobs.'
                            : 'New jobs arrive all day — we\'ll notify you.',
                        actionLabel: me.skills.isEmpty ? 'Add skills' : null,
                        onAction: me.skills.isEmpty ? () => push(context, const EditProfileScreen()) : null,
                      ),
                    ),
                  )
                else
                  for (final j in _matching!)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: JobCard(job: j, viewerId: me.id, onTap: () => _open(j))),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _stats(BuildContext context, User me) {
    final s = _summary;
    final p = context.palette;
    return [
      StatTile(
          icon: Icons.account_balance_wallet_rounded,
          value: s == null ? '—' : Fmt.compactMoney(s['earnings'] ?? 0),
          label: 'Earned on SureFix',
          color: p.success),
      StatTile(
          icon: Icons.handyman_rounded,
          value: '${s?['activeJobs'] ?? '—'}',
          label: 'Active jobs',
          color: p.warning,
          onTap: () => HomeShell.goTo(context, 2)),
      StatTile(
          icon: Icons.request_quote_rounded,
          value: '${s?['pendingBids'] ?? '—'}',
          label: 'Quotes awaiting reply',
          color: context.colors.primary,
          onTap: () => HomeShell.goTo(context, 2)),
      StatTile(
        icon: Icons.star_rounded,
        value: me.ratingCount == 0 ? 'New' : me.rating.toStringAsFixed(1),
        label: '${Fmt.plural(me.ratingCount, 'review')} · ${s?['completedJobs'] ?? me.jobsCompleted} done',
        color: p.star,
      ),
    ];
  }

  Widget _jobColumn(BuildContext context, User me,
      {required String title,
      required List<Job>? jobs,
      required Widget empty,
      String? action,
      VoidCallback? onAction,
      bool showClient = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title, padding: const EdgeInsets.fromLTRB(4, 0, 0, 10), actionLabel: action, onAction: onAction),
      if (jobs == null)
        const SkeletonCard()
      else if (jobs.isEmpty)
        Card(child: empty)
      else
        for (final j in jobs) ...[
          JobCard(job: j, viewerId: me.id, showClient: showClient, onTap: () => _open(j)),
          const SizedBox(height: 12),
        ],
    ]);
  }

  /// Website layout: banner with availability, stats row, then direct
  /// requests beside matching jobs.
  Widget _wide(BuildContext context, User me) {
    final p = context.palette;
    final prompts = [
      if (!me.isVerified)
        _prompt(
          context,
          icon: Icons.verified_user_rounded,
          color: p.info,
          title: me.kycStatus == 'pending' ? 'Verification in review' : 'Get verified',
          body: me.kycStatus == 'pending'
              ? 'We\'ll notify you as soon as it\'s approved.'
              : 'Verified technicians get a badge and rank higher in Smart Match.',
          onTap: () => push(context, const KycScreen()),
        ),
      if (me.profileCompleteness < 1)
        _prompt(
          context,
          icon: Icons.auto_graph_rounded,
          color: Brand.accent,
          title: 'Profile ${(me.profileCompleteness * 100).round()}% complete',
          body: 'Add ${me.missingProfileItems.take(2).join(' and ')} to appear in more AI matches.',
          onTap: () => push(context, const EditProfileScreen()),
        ),
    ];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 28, bottom: 56),
          child: WebContent(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DashboardBanner(
                child: Row(children: [
                  AppAvatar(name: me.name, url: me.avatar, size: 64, verified: me.isVerified),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hi, ${me.firstName}',
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(me.headline.isEmpty ? 'Technician' : me.headline,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15)),
                    ]),
                  ),
                  Container(
                    width: 340,
                    padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Icon(me.isAvailable ? Icons.circle : Icons.do_not_disturb_on_rounded,
                          size: 14, color: me.isAvailable ? const Color(0xFF32D583) : Colors.white60),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(me.isAvailable ? 'Available for new jobs' : 'Busy — not taking new jobs',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      Switch(value: me.isAvailable, onChanged: _toggling ? null : _toggleAvailability),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              ColumnsGrid(columns: 4, rowHeight: 130, children: _stats(context, me)),
              if (prompts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 0; i < prompts.length; i++) ...[if (i > 0) const SizedBox(width: 20), Expanded(child: prompts[i])],
                ]),
              ],
              const SizedBox(height: 28),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _jobColumn(
                    context,
                    me,
                    title: 'Direct requests${_requests == null || _requests!.isEmpty ? '' : ' (${_requests!.length})'}',
                    jobs: _requests,
                    showClient: true,
                    empty: const EmptyState(
                        compact: true,
                        icon: Icons.person_pin_outlined,
                        title: 'No requests right now',
                        message: 'Clients who pick you from Smart Match will appear here.'),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: _jobColumn(
                    context,
                    me,
                    title: 'Jobs matching your skills',
                    jobs: _matching,
                    action: 'Find work',
                    onAction: () => HomeShell.goTo(context, 1),
                    empty: EmptyState(
                      compact: true,
                      icon: Icons.search_off_rounded,
                      title: me.skills.isEmpty ? 'Add your skills' : 'No open jobs in your trades',
                      message:
                          me.skills.isEmpty ? 'Tell us what you do to see matching jobs.' : 'New jobs arrive all day — we\'ll notify you.',
                      actionLabel: me.skills.isEmpty ? 'Add skills' : null,
                      onAction: me.skills.isEmpty ? () => push(context, const EditProfileScreen()) : null,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _prompt(BuildContext context,
          {required IconData icon, required Color color, required String title, required String body, required VoidCallback onTap}) =>
      Padding(
        padding: context.isWide ? const EdgeInsets.only(top: 12) : const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(body, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      );
}
