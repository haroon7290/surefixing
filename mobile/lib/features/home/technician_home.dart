import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../account/kyc_screen.dart';
import '../jobs/job_widgets.dart';
import '../shell/shell.dart';
import 'home_widgets.dart';

class _Data {
  final Json summary;
  final List<Job> requests;
  final List<Job> active;
  final List<Job> market;
  const _Data(this.summary, this.requests, this.active, this.market);
}

/// The technician's dashboard: earnings, requests waiting for an answer,
/// jobs in progress and fresh jobs that match their skills.
class TechnicianHome extends StatefulWidget {
  const TechnicianHome({super.key});

  @override
  State<TechnicianHome> createState() => _TechnicianHomeState();
}

class _TechnicianHomeState extends State<TechnicianHome> {
  final _view = GlobalKey<AsyncViewState<_Data>>();
  bool _savingAvailability = false;

  Future<_Data> _load() async {
    final results = await Future.wait([
      Api.map('/api/users/me/summary'),
      Api.list('/api/jobs', query: {'view': 'requests'}),
      Api.list('/api/jobs', query: {'mine': 1, 'status': 'in_progress'}),
      Api.list('/api/jobs', query: {'matching': 1, 'limit': 6}),
    ]);
    List<Job> jobs(int i) => (results[i] as List<Json>).map(Job.fromJson).toList();
    return _Data(results[0] as Json, jobs(1), jobs(2), jobs(3));
  }

  Future<void> _setAvailable(bool value) async {
    setState(() => _savingAvailability = true);
    try {
      await Session.instance.updateProfile({'isAvailable': value});
      toast(value ? 'You are visible for new jobs' : 'You are marked as busy', kind: ToastKind.success);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _savingAvailability = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return AppPage(
      body: AsyncView<_Data>(
        key: _view,
        load: _load,
        events: const {...Live.jobs, ...Live.wallet},
        builder: (context, d) => ListenableBuilder(
          listenable: Session.instance,
          builder: (context, _) {
            final me = Session.instance.user!;
            final s = d.summary;
            final me0 = me.id;
            final fresh = d.market.where((j) => j.bidBy(me0) == null).toList();

            final hero = EarningsHero(
              label: 'Earned this month',
              amount: dbl(s['earningsThisMonth']),
              caption: '${money(dbl(s['earnings']))} all time from ${plural(integer(s['completedJobs']), 'job')}',
              figures: [
                HeroFigure(label: 'In escrow', value: moneyCompact(dbl(s['inEscrow'])), icon: AppIcons.lock, onTap: () => openSection(context, 'wallet')),
                HeroFigure(label: 'Wallet', value: moneyCompact(me.walletBalance), icon: AppIcons.wallet, onTap: () => openSection(context, 'wallet')),
                HeroFigure(label: 'Rating', value: me.ratingCount == 0 ? 'New' : me.rating.toStringAsFixed(1), icon: AppIcons.starFill),
              ],
            );
            final stats = [
              StatCard(label: 'Requests for you', value: '${integer(s['requests'])}', icon: AppIcons.bolt, tone: Tone.brand, onTap: () => openSection(context, 'work')),
              StatCard(label: 'Active jobs', value: '${integer(s['activeJobs'])}', icon: AppIcons.wrench, tone: Tone.info, onTap: () => openSection(context, 'work')),
              StatCard(label: 'Quotes waiting', value: '${integer(s['pendingBids'])}', icon: AppIcons.hourglass, tone: Tone.warning, onTap: () => openSection(context, 'work')),
              StatCard(label: 'Completed', value: '${integer(s['completedJobs'])}', icon: AppIcons.success, tone: Tone.success, onTap: () => openSection(context, 'work')),
            ];

            return PageList(
              onRefresh: () => _view.currentState!.reload(),
              children: [
                HomeHeader(
                  subtitle: me.isAvailable ? 'You are visible for new jobs.' : 'You are marked as busy.',
                  actions: [
                    Tooltip(
                      message: me.isAvailable ? 'Available for work' : 'Busy',
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (wide) Text(me.isAvailable ? 'Available' : 'Busy', style: context.text.titleSmall),
                        Switch(value: me.isAvailable, onChanged: _savingAvailability ? null : _setAvailable),
                      ]),
                    ),
                  ],
                ),
                if (!me.verified) ...[
                  Notice(
                    me.kycStatus == 'pending'
                        ? 'Your documents are being reviewed. You will get the verified seal once approved.'
                        : 'Verified technicians rank higher and win more jobs. It takes two minutes.',
                    title: me.kycStatus == 'pending' ? 'Verification in review' : 'Get the verified seal',
                    tone: me.kycStatus == 'pending' ? Tone.info : Tone.brand,
                    icon: AppIcons.verified,
                    action: me.kycStatus == 'pending' ? null : Btn('Verify my identity', kind: BtnKind.dark, size: BtnSize.sm, onPressed: () => push(context, const KycScreen())),
                  ),
                  Gap.h12,
                ],
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 6, child: hero),
                    Gap.w16,
                    Expanded(flex: 5, child: AutoGrid(minWidth: 150, gap: 16, maxColumns: 2, children: stats)),
                  ])
                else ...[
                  hero,
                  Gap.h12,
                  AutoGrid(minWidth: 150, gap: 12, maxColumns: 2, children: stats),
                ],
                if (d.requests.isNotEmpty) ...[
                  const SectionTitle('Requested you directly'),
                  AutoGrid(minWidth: 320, gap: 12, maxColumns: 3, children: [for (final j in d.requests) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
                ],
                if (d.active.isNotEmpty) ...[
                  SectionTitle('Jobs in progress', action: 'My work', onAction: () => openSection(context, 'work')),
                  AutoGrid(minWidth: 320, gap: 12, maxColumns: 3, children: [for (final j in d.active) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
                ],
                SectionTitle('New jobs for you', action: 'Find jobs', onAction: () => openSection(context, 'find')),
                if (fresh.isEmpty)
                  Panel(
                    child: EmptyState(
                      compact: true,
                      icon: AppIcons.search,
                      title: 'No new jobs match your skills',
                      message: me.skills.isEmpty ? 'Add your skills to your profile so matching jobs show up here.' : 'New jobs appear here the moment they are posted.',
                      action: Btn('Browse all jobs', kind: BtnKind.dark, onPressed: () => openSection(context, 'find')),
                    ),
                  )
                else
                  AutoGrid(minWidth: 320, gap: 12, maxColumns: 3, children: [for (final j in fresh.take(6)) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
              ],
            );
          },
        ),
      ),
    );
  }
}
