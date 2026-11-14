import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../location/location_picker.dart';
import 'job_widgets.dart';

/// Minimum budgets offered in the job filters.
const _budgets = [0, 2000, 5000, 10000];

class JobFilters {
  final bool matching;
  final String category;
  final Set<String> urgency;
  final int minBudget;
  final int radius;
  const JobFilters({this.matching = false, this.category = '', this.urgency = const {}, this.minBudget = 0, this.radius = 0});

  JobFilters copy({bool? matching, String? category, Set<String>? urgency, int? minBudget, int? radius}) => JobFilters(
        matching: matching ?? this.matching,
        category: category ?? this.category,
        urgency: urgency ?? this.urgency,
        minBudget: minBudget ?? this.minBudget,
        radius: radius ?? this.radius,
      );

  int get count => [matching && category.isEmpty, category.isNotEmpty, urgency.isNotEmpty, minBudget > 0, radius > 0].where((on) => on).length;
  String get key => '$matching|$category|${(urgency.toList()..sort()).join(',')}|$minBudget|$radius';
}

/// The open marketplace for technicians: search and filter jobs to quote on
/// by distance, trade, urgency and budget.
class FindJobsScreen extends StatefulWidget {
  const FindJobsScreen({super.key});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Job>>>();
  late JobFilters _f = JobFilters(matching: Session.instance.user?.skills.isNotEmpty ?? false);
  String _query = '';
  String _sort = 'newest';
  Timer? _debounce;

  static const _sorts = {'newest': 'Newest first', 'distance': 'Nearest', 'budget': 'Highest budget', 'oldest': 'Oldest first'};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String get _effectiveSort => _sort == 'distance' && !Locations.instance.known ? 'newest' : _sort;

  Map<String, String> get _sortOptions => Locations.instance.known ? _sorts : (Map.of(_sorts)..remove('distance'));

  Future<List<Job>> _load(JobFilters f, String sort) async {
    final rows = await Api.list('/api/jobs', query: {
      'q': _query,
      'category': f.category,
      'matching': f.matching && f.category.isEmpty ? 1 : null,
      'urgency': f.urgency.isEmpty ? null : f.urgency.join(','),
      'minBudget': f.minBudget > 0 ? f.minBudget : null,
      'sort': sort,
      ...Locations.instance.query(),
      'limit': 60,
    });
    return rows.map(Job.fromJson).toList();
  }

  void _apply(JobFilters f) {
    setState(() => _f = f);
    Locations.instance.setRadius(f.radius);
  }

  List<Widget> _groups(BuildContext context, JobFilters f, ValueChanged<JobFilters> set) {
    final me = Session.instance.user!;
    return [
      FilterGroup('Distance', hint: 'From where you work: your saved location unless you pick another.', child: DistanceFilter(radius: f.radius, onRadius: (km) => set(f.copy(radius: km)))),
      FilterGroup(
        'Type of work',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (me.skills.isNotEmpty) ...[
            FilterToggle(
              label: 'Matches my skills',
              subtitle: me.skills.map(skillLabel).take(3).join(', '),
              icon: AppIcons.target,
              value: f.matching && f.category.isEmpty,
              onChanged: (v) => set(f.copy(matching: v, category: '')),
            ),
            Gap.h8,
          ],
          Pills<CatalogItem>(
            values: serviceCategories,
            label: (c) => c.label,
            selected: f.category.isEmpty ? null : serviceCategory(f.category),
            onTap: (c) => set(f.copy(category: f.category == c.key ? '' : c.key, matching: false)),
          ),
        ]),
      ),
      FilterGroup(
        'Urgency',
        child: Pills<String>(
          values: urgencyLevels,
          label: urgencyLabel,
          selectedSet: f.urgency,
          onTap: (u) => set(f.copy(urgency: f.urgency.contains(u) ? ({...f.urgency}..remove(u)) : {...f.urgency, u})),
        ),
      ),
      FilterGroup(
        'Budget',
        child: Pills<int>(values: _budgets, label: (b) => b == 0 ? 'Any budget' : '${money(b)}+', selected: f.minBudget, onTap: (b) => set(f.copy(minBudget: b))),
      ),
    ];
  }

  Future<void> _openSheet(JobFilters f) async {
    final next = await showFilterSheet<JobFilters>(context, initial: f, cleared: const JobFilters(), groups: _groups);
    if (next != null) _apply(next);
  }

  String _summary(int n) {
    final loc = Locations.instance;
    final from = loc.searchFrom;
    final what = plural(n, 'open job');
    if (from != null && loc.radiusKm > 0) return '$what within ${loc.radiusKm} km of ${from.label}';
    return what;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Locations.instance,
        builder: (context, _) {
          final loc = Locations.instance;
          final f = _f.copy(radius: loc.radiusKm);
          final sort = _effectiveSort;
          final from = loc.searchFrom;
          final filtered = f.count > 0 || _query.isNotEmpty;
          final sortMenu = SortMenu<String>(options: _sortOptions, value: sort, onChanged: (v) => setState(() => _sort = v));
          return AppPage(
            title: 'Find jobs',
            subtitle: 'Open jobs waiting for quotes, with how far each one is. New ones appear live.',
            body: FilterLayout<List<Job>>(
              viewKey: _view,
              token: '$_query|${f.key}|$sort|${from?.point.lat},${from?.point.lng}',
              load: () => _load(f, sort),
              events: const {'job:new', 'job:status', 'job:hired'},
              search: SearchBox(
                hint: 'Search jobs: "tap", "AC", "wiring"…',
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
                },
              ),
              panel: FilterPanel(active: f.count, onReset: () => _apply(const JobFilters()), children: _groups(context, f, _apply)),
              phoneBar: [
                const LocationChip(),
                BarButton('Filters', icon: AppIcons.filter, badge: f.count, onTap: () => _openSheet(f)),
                sortMenu,
              ],
              results: (context, jobs) => jobs.isEmpty
                  ? [
                      EmptyState(
                        icon: AppIcons.search,
                        title: 'No open jobs match',
                        message: loc.radiusKm > 0
                            ? 'Nothing within ${loc.radiusKm} km right now. Try a wider distance.'
                            : (f.matching && f.category.isEmpty ? 'Nothing for your skills right now. Try all categories.' : 'Try another search or filter.'),
                        action: filtered ? Btn('Show all jobs', kind: BtnKind.dark, onPressed: () => _apply(const JobFilters())) : null,
                      ),
                    ]
                  : [
                      ResultsHeader(_summary(jobs.length), sort: sortMenu),
                      AutoGrid(minWidth: 340, gap: 12, maxColumns: 2, children: [for (final j in jobs) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
                    ],
            ),
          );
        },
      );
}

/// The technician's own pipeline: hired jobs, direct requests, quotes out
/// and history.
class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  final _view = GlobalKey<AsyncViewState<Map<String, List<Job>>>>();
  String _tab = 'active';

  static const _tabs = {'active': 'Active', 'requests': 'Requests', 'quotes': 'Quotes', 'done': 'History'};

  Future<Map<String, List<Job>>> _load() async {
    final results = await Future.wait([
      Api.list('/api/jobs', query: {'mine': 1, 'status': 'in_progress'}),
      Api.list('/api/jobs', query: {'view': 'requests'}),
      Api.list('/api/jobs', query: {'view': 'bids'}),
      Api.list('/api/jobs', query: {'mine': 1, 'status': 'completed,cancelled', 'limit': 60}),
    ]);
    List<Job> jobs(int i) => results[i].map(Job.fromJson).toList();
    return {'active': jobs(0), 'requests': jobs(1), 'quotes': jobs(2), 'done': jobs(3)};
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'My work',
        subtitle: 'Jobs you were hired for, requests and quotes you have sent.',
        body: AsyncView<Map<String, List<Job>>>(
          key: _view,
          load: _load,
          events: Live.jobs,
          builder: (context, data) {
            final jobs = data[_tab] ?? const <Job>[];
            final (icon, title, message) = switch (_tab) {
              'requests' => (AppIcons.bolt, 'No direct requests', 'When a client asks for you by name it shows up here.'),
              'quotes' => (AppIcons.tag, 'No quotes waiting', 'Quotes you send appear here until the client decides.'),
              'done' => (AppIcons.success, 'No finished jobs yet', 'Completed jobs and their reviews will be listed here.'),
              _ => (AppIcons.work, 'No jobs in progress', 'Win a job by sending a good quote from Find jobs.'),
            };
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PagePad(
                child: Pills<String>(
                  scroll: true,
                  values: _tabs.keys.toList(),
                  label: (k) => (data[k]?.isEmpty ?? true) ? _tabs[k]! : '${_tabs[k]} · ${data[k]!.length}',
                  selected: _tab,
                  onTap: (k) => setState(() => _tab = k),
                ),
              ),
              Expanded(
                child: jobs.isEmpty
                    ? EmptyState(icon: icon, title: title, message: message)
                    : PageList(
                        onRefresh: () => _view.currentState!.reload(),
                        children: [
                          AutoGrid(minWidth: 340, gap: 12, maxColumns: 3, children: [for (final j in jobs) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
                        ],
                      ),
              ),
            ]);
          },
        ),
      );
}
