import 'package:flutter/material.dart';

import '../../kit.dart';
import '../home/home_widgets.dart';
import '../shell/shell.dart';

class _Data {
  final Json stats;
  final Json ai;
  const _Data(this.stats, this.ai);
}

/// The admin's control room: what needs attention, how the marketplace is
/// doing, and what SureFix has earned.
class AdminOverview extends StatefulWidget {
  const AdminOverview({super.key});

  @override
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> {
  final _view = GlobalKey<AsyncViewState<_Data>>();

  Future<_Data> _load() async {
    final results = await Future.wait([Api.map('/api/admin/stats'), Api.map('/api/ai/status').catchError((_) => <String, dynamic>{})]);
    return _Data(results[0], results[1]);
  }

  static String _weekday(String isoDate) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][(DateTime.tryParse(isoDate)?.weekday ?? 1) - 1];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      body: AsyncView<_Data>(
        key: _view,
        load: _load,
        events: const {...Live.admin, ...Live.jobs},
        builder: (context, d) {
          final s = d.stats;
          final wide = context.isWide;
          List<Json> series(String key) => asJsonList(s[key]);
          final roles = asJson(s['usersByRole']);
          final jobs = asJson(s['jobsByStatus']);
          final paidBy = asJson(s['jobsPaidBy']);
          final cats = asJsonList(s['topCategories']);
          final maxCat = cats.fold<int>(1, (a, x) => integer(x['count']) > a ? integer(x['count']) : a);
          final aiOnline = d.ai['online'] == true;

          Widget chart(String title, String key, {bool isMoney = false, Color? color}) {
            final rows = series(key);
            final total = rows.fold<double>(0, (a, r) => a + dbl(r['count']));
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: context.text.bodySmall!.copyWith(color: c.body)),
                Text(isMoney ? money(total) : count(total), style: context.text.headlineMedium),
                Text('last 7 days', style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
                Gap.h12,
                BarChart(
                  values: [for (final r in rows) dbl(r['count'])],
                  labels: [for (final r in rows) _weekday(str(r['date']))],
                  format: (v) => isMoney ? moneyCompact(v).replaceFirst('Rs ', '') : '${v.round()}',
                  height: 130,
                  color: color,
                ),
              ]),
            );
          }

          final attention = [
            StatCard(
              label: 'Deposits to check',
              value: '${integer(s['pendingDeposits'])}',
              icon: AppIcons.topUp,
              tone: integer(s['pendingDeposits']) > 0 ? Tone.warning : Tone.success,
              caption: integer(s['pendingDeposits']) > 0 ? money(dbl(s['pendingDepositsAmount'])) : 'All clear',
              onTap: () => openSection(context, 'payments'),
            ),
            StatCard(
              label: 'Withdrawals to pay',
              value: '${integer(s['pendingWithdrawals'])}',
              icon: AppIcons.withdraw,
              tone: integer(s['pendingWithdrawals']) > 0 ? Tone.warning : Tone.success,
              caption: integer(s['pendingWithdrawals']) > 0 ? money(dbl(s['pendingWithdrawalsAmount'])) : 'All clear',
              onTap: () => openSection(context, 'payments'),
            ),
            StatCard(
                label: 'IDs to verify',
                value: '${integer(s['pendingKyc'])}',
                icon: AppIcons.verify,
                tone: integer(s['pendingKyc']) > 0 ? Tone.warning : Tone.success,
                onTap: () => openSection(context, 'verify')),
            StatCard(
                label: 'Open reports',
                value: '${integer(s['openReports'])}',
                icon: AppIcons.reports,
                tone: integer(s['openReports']) > 0 ? Tone.danger : Tone.success,
                onTap: () => openSection(context, 'reports')),
            StatCard(
                label: 'Users',
                value: count(integer(s['users'])),
                icon: AppIcons.users,
                tone: Tone.info,
                caption: '${integer(s['suspendedUsers'])} suspended',
                onTap: () => openSection(context, 'users')),
            StatCard(
                label: 'Jobs',
                value: count(integer(s['jobs'])),
                icon: AppIcons.jobs,
                tone: Tone.brand,
                caption: '${integer(jobs['in_progress'])} in progress',
                onTap: () => openSection(context, 'all-jobs')),
            StatCard(label: 'Tools listed', value: count(integer(s['tools'])), icon: AppIcons.tools, caption: '${integer(s['rentals'])} rentals', onTap: () => openSection(context, 'all-tools')),
            StatCard(label: 'Avg technician rating', value: dbl(s['avgTechnicianRating']) > 0 ? dbl(s['avgTechnicianRating']).toStringAsFixed(2) : '—', icon: AppIcons.starFill, tone: Tone.warning),
          ];

          final revenue = EarningsHero(
            label: 'Platform revenue',
            amount: dbl(s['platformRevenue']),
            caption: '${dbl(s['feePercent']).round()}% service fee on wallet payments',
            figures: [
              HeroFigure(label: 'Held in escrow', value: moneyCompact(dbl(s['escrowHeld'])), icon: AppIcons.lock, onTap: () => openSection(context, 'payments')),
              HeroFigure(label: 'Jobs value', value: moneyCompact(dbl(s['jobsValue'])), icon: AppIcons.work),
              HeroFigure(label: 'Rentals value', value: moneyCompact(dbl(s['rentalsValue'])), icon: AppIcons.tools),
            ],
          );

          final breakdown = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Who is on SureFix', style: context.text.titleMedium),
              Gap.h12,
              SegmentBar(segments: [
                Segment('Customers', dbl(roles['client']), const Color(0xFF2E7BE8)),
                Segment('Technicians', dbl(roles['technician']), c.brand),
                Segment('Suppliers', dbl(roles['supplier']), const Color(0xFF12A679)),
                Segment('Admins', dbl(roles['admin']), c.muted),
              ]),
              Gap.h24,
              Text('Jobs by status', style: context.text.titleMedium),
              Gap.h12,
              SegmentBar(segments: [
                Segment('Getting quotes', dbl(jobs['pending']), const Color(0xFF2E7BE8)),
                Segment('In progress', dbl(jobs['in_progress']), c.brand),
                Segment('Completed', dbl(jobs['completed']), const Color(0xFF12A679)),
                Segment('Cancelled', dbl(jobs['cancelled']), c.muted),
              ]),
              Gap.h24,
              Text('How completed jobs were paid', style: context.text.titleMedium),
              Gap.h12,
              SegmentBar(segments: [
                Segment('Wallet (escrow)', dbl(paidBy['wallet']), c.brand),
                Segment('Cash', dbl(paidBy['cash']), c.muted),
              ]),
            ]),
          );

          final categories = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Most requested services', style: context.text.titleMedium),
              Gap.h8,
              for (final x in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    IconTile(serviceCategory(str(x['category'])).icon, color: serviceCategory(str(x['category'])).color, size: 34),
                    Gap.w12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Expanded(child: Text(serviceCategory(str(x['category'])).label, style: context.text.titleSmall)),
                          Text(plural(integer(x['count']), 'job'), style: context.text.bodySmall),
                        ]),
                        Gap.h6,
                        ProgressLine(integer(x['count']) / maxCat, color: serviceCategory(str(x['category'])).color),
                      ]),
                    ),
                  ]),
                ),
            ]),
          );

          final ai = Panel(
            child: Row(children: [
              IconTile(AppIcons.sparkleFill, tone: aiOnline ? Tone.success : Tone.warning),
              Gap.w12,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('AI matching service', style: context.text.titleSmall),
                  Text(
                    aiOnline ? 'Online${d.ai['version'] != null ? ' · v${d.ai['version']}' : ''} · ${str(d.ai['url'])}' : 'Offline — the built-in fallback engine is answering instead',
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              Pill(aiOnline ? 'Online' : 'Fallback', tone: aiOnline ? Tone.success : Tone.warning, dot: true),
            ]),
          );

          return PageList(
            onRefresh: () => _view.currentState!.reload(),
            children: [
              const HomeHeader(subtitle: 'Marketplace health, trust queue and revenue.'),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: revenue),
                  Gap.w16,
                  Expanded(flex: 7, child: AutoGrid(minWidth: 170, gap: 16, maxColumns: 3, children: attention)),
                ])
              else ...[
                revenue,
                Gap.h12,
                AutoGrid(minWidth: 150, gap: 12, maxColumns: 2, children: attention),
              ],
              const SectionTitle('This week'),
              AutoGrid(minWidth: 280, gap: 16, maxColumns: 3, children: [
                chart('New sign-ups', 'signupsLast7Days', color: const Color(0xFF2E7BE8)),
                chart('Jobs posted', 'jobsLast7Days'),
                chart('Fees earned', 'revenueLast7Days', isMoney: true, color: const Color(0xFF12A679)),
              ]),
              const SectionTitle('Marketplace'),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: breakdown),
                  Gap.w16,
                  Expanded(child: Column(children: [categories, Gap.h16, ai]))
                ])
              else ...[breakdown, Gap.h12, categories, Gap.h12, ai],
            ],
          );
        },
      ),
    );
  }
}
