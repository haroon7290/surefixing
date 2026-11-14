import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../jobs/job_widgets.dart';
import '../jobs/post_job_screen.dart';
import '../shell/shell.dart';
import '../technicians/tech_widgets.dart';
import '../technicians/technicians_screen.dart';
import '../tools/tool_widgets.dart';
import 'home_widgets.dart';

class _Data {
  final Json summary;
  final List<Job> jobs;
  final List<User> techs;
  final List<Tool> tools;
  final bool nearby; // techs are within 25 km of the search place
  const _Data(this.summary, this.jobs, this.techs, this.tools, {this.nearby = false});
}

/// The customer's dashboard: start a job, see what needs attention, and
/// browse technicians and tools.
class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final _view = GlobalKey<AsyncViewState<_Data>>();

  @override
  void initState() {
    super.initState();
    Locations.instance.addListener(_placeChanged);
  }

  @override
  void dispose() {
    Locations.instance.removeListener(_placeChanged);
    super.dispose();
  }

  void _placeChanged() {
    if (mounted) setState(() {});
  }

  Future<_Data> _load() async {
    final city = Session.instance.user?.city ?? '';
    final near = Locations.instance.query(withRadius: false);
    final results = await Future.wait([
      Api.map('/api/users/me/summary'),
      Api.list('/api/jobs', query: {'status': 'pending,in_progress', 'limit': 6}),
      // Near the search place when there is one (25 km), else in their city.
      Api.list('/api/users/technicians', query: {'sort': 'rating', 'limit': 8, ...near, if (near.isNotEmpty) 'radius': 25 else 'city': city}),
      Api.list('/api/tools', query: {'sort': 'popular', 'limit': 8, ...near}),
    ]);
    var techs = (results[2] as List<Json>).map(User.fromJson).toList();
    var nearby = near.isNotEmpty;
    if (techs.length < 3 && (near.isNotEmpty || city.isNotEmpty)) {
      techs = (await Api.list('/api/users/technicians', query: {'sort': 'rating', 'limit': 8, ...near})).map(User.fromJson).toList();
      nearby = false;
    }
    return _Data(results[0] as Json, (results[1] as List<Json>).map(Job.fromJson).toList(), techs, (results[3] as List<Json>).map(Tool.fromJson).toList(), nearby: nearby);
  }

  void _post([String? category]) => push(context, PostJobScreen(category: category), path: '/post-job');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    final from = Locations.instance.searchFrom;
    return AppPage(
      body: AsyncView<_Data>(
        key: _view,
        token: '${from?.point.lat},${from?.point.lng}',
        load: _load,
        events: const {...Live.jobs, ...Live.rentals},
        builder: (context, d) {
          final toConfirm = d.jobs.where((j) => j.awaitingConfirmation).toList();
          final active = d.jobs;

          final ask = HeroCard(
            onTap: _post,
            padding: EdgeInsets.all(wide ? 28 : 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('WHAT NEEDS FIXING?', style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.brand)),
              Gap.h8,
              Text('Describe it. We find\nthe right person.', style: (wide ? context.text.displaySmall : context.text.headlineMedium)!.copyWith(color: c.onHero)),
              Gap.h16,
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                decoration: BoxDecoration(color: c.onHero.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: c.heroLine)),
                child: Row(children: [
                  Icon(AppIcons.sparkleFill, size: 18, color: c.brand),
                  Gap.w12,
                  Expanded(
                      child: Text('e.g. My kitchen tap is leaking…',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, fontSize: 15, fontWeight: FontWeight.w500, color: c.onHeroMuted))),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(12)),
                    child: Icon(AppIcons.forward, size: 18, color: c.onBrand),
                  ),
                ]),
              ),
            ]),
          );

          final tiles = [
            StatCard(label: 'Wallet balance', value: moneyCompact(dbl(d.summary['walletBalance'])), icon: AppIcons.wallet, tone: Tone.brand, onTap: () => openSection(context, 'wallet')),
            StatCard(label: 'Active rentals', value: '${integer(d.summary['activeRentals'])}', icon: AppIcons.rentals, tone: Tone.info, onTap: () => openSection(context, 'rentals')),
          ];

          return PageList(
            onRefresh: () => _view.currentState!.reload(),
            children: [
              HomeHeader(
                subtitle: 'Here is what is happening with your home.',
                actions: [if (wide) Btn('Post a job', icon: AppIcons.add, onPressed: _post)],
              ),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 7, child: ask),
                  Gap.w16,
                  Expanded(flex: 4, child: Column(children: [tiles[0], Gap.h16, tiles[1]])),
                ])
              else ...[
                ask,
                Gap.h12,
                Row(children: [Expanded(child: tiles[0]), Gap.w12, Expanded(child: tiles[1])]),
              ],
              for (final job in toConfirm) ...[
                Gap.h12,
                Notice(
                  '${job.technician?.name ?? 'Your technician'} finished "${job.title}". Confirm it to release the payment.',
                  title: 'Waiting for your confirmation',
                  tone: Tone.warning,
                  action: Btn('Review & confirm', kind: BtnKind.dark, size: BtnSize.sm, onPressed: () => openJob(context, job.id)),
                ),
              ],
              SectionTitle('Your jobs', action: active.isEmpty ? null : 'See all', onAction: () => openSection(context, 'jobs')),
              if (active.isEmpty)
                Panel(
                  child: EmptyState(
                    compact: true,
                    icon: AppIcons.jobs,
                    title: 'No jobs in progress',
                    message: 'Post your first job and get quotes from verified technicians.',
                    action: Btn('Post a job', icon: AppIcons.add, onPressed: _post),
                  ),
                )
              else
                AutoGrid(minWidth: 320, gap: 12, maxColumns: 3, children: [for (final j in active.take(wide ? 6 : 3)) JobCard(j, onTap: () => openJob(context, j.id))]),
              const SectionTitle('Browse services'),
              AutoGrid(
                minWidth: wide ? 150 : 76,
                gap: wide ? 12 : 8,
                maxColumns: wide ? 6 : 4,
                children: [
                  for (final cat in serviceCategories.take(wide ? 12 : 8))
                    Semantics(
                      button: true,
                      label: cat.label,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => push(context, TechniciansScreen(category: cat.key)),
                        borderRadius: BorderRadius.circular(R.lg),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            IconTile(cat.icon, color: cat.color, size: wide ? 58 : 54),
                            Gap.h8,
                            Text(cat.label.split(' ').first, style: context.text.labelMedium!.copyWith(color: c.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
              if (d.techs.isNotEmpty) ...[
                SectionTitle(d.nearby ? 'Top technicians near you' : 'Top technicians', action: 'See all', onAction: () => openSection(context, 'technicians')),
                if (wide)
                  AutoGrid(minWidth: 280, gap: 16, maxColumns: 4, children: [for (final t in d.techs.take(4)) TechCard(t, onTap: () => openTechnician(context, t.id))])
                else
                  HScroll(height: 172, children: [for (final t in d.techs) TechTile(t, onTap: () => openTechnician(context, t.id))]),
              ],
              if (d.tools.isNotEmpty) ...[
                SectionTitle('Rent a tool', action: 'See all', onAction: () => openSection(context, 'tools')),
                if (wide)
                  AutoGrid(minWidth: 220, gap: 16, maxColumns: 4, itemHeight: 290, children: [for (final t in d.tools.take(4)) ToolCard(t, onTap: () => openTool(context, t.id))])
                else
                  HScroll(height: 236, children: [for (final t in d.tools) SizedBox(width: 172, child: ToolCard(t, onTap: () => openTool(context, t.id)))]),
              ],
            ],
          );
        },
      ),
    );
  }
}
