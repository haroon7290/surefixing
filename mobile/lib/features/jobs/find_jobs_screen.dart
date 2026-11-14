import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'job_widgets.dart';

/// The open marketplace for technicians: search and filter jobs to quote on.
class FindJobsScreen extends StatefulWidget {
  const FindJobsScreen({super.key});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Job>>>();
  String _query = '';
  String? _category;
  bool _matching = Session.instance.user?.skills.isNotEmpty ?? false;
  bool _nearby = false;
  String _sort = 'newest';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Job>> _load() async {
    final me = Session.instance.user!;
    final rows = await Api.list('/api/jobs', query: {
      'q': _query,
      'category': _category,
      'matching': _matching && _category == null ? 1 : null,
      'city': _nearby ? me.city : null,
      'sort': _sort,
      'limit': 60,
    });
    return rows.map(Job.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.user!;
    final token = '$_query|$_category|$_matching|$_nearby|$_sort';
    return AppPage(
      title: 'Find jobs',
      subtitle: 'Open jobs waiting for quotes. New ones appear live.',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Sort',
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'newest', child: Text('Newest first')),
            PopupMenuItem(value: 'budget', child: Text('Highest budget')),
            PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
          ],
          child: const IgnorePointer(child: RoundBtn(AppIcons.sort, tooltip: 'Sort')),
        ),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: SearchBox(
            hint: 'Search jobs: "tap", "AC", "wiring"…',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        PagePad(
          child: FilterBar(children: [
            if (me.skills.isNotEmpty) ...[
              Pills<bool>(
                  values: const [true],
                  label: (_) => 'My skills',
                  icon: (_) => AppIcons.target,
                  selected: _matching && _category == null ? true : null,
                  onTap: (_) => setState(() {
                        _matching = !_matching || _category != null;
                        _category = null;
                      })),
            ],
            if (me.city.isNotEmpty) ...[
              Pills<bool>(values: const [true], label: (_) => 'In ${me.city}', icon: (_) => AppIcons.pin, selected: _nearby ? true : null, onTap: (_) => setState(() => _nearby = !_nearby)),
            ],
            Pills<CatalogItem>(
              values: serviceCategories,
              label: (c) => c.label,
              selected: _category == null ? null : serviceCategory(_category!),
              onTap: (c) => setState(() => _category = _category == c.key ? null : c.key),
            ),
          ]),
        ),
        Expanded(
          child: AsyncView<List<Job>>(
            key: _view,
            token: token,
            load: _load,
            events: const {'job:new', 'job:status', 'job:hired'},
            builder: (context, jobs) => jobs.isEmpty
                ? EmptyState(
                    icon: AppIcons.search,
                    title: 'No open jobs match',
                    message: _matching && _category == null ? 'Nothing for your skills right now. Try all categories.' : 'Try another search or filter.',
                    action: _matching || _category != null || _nearby || _query.isNotEmpty
                        ? Btn('Show all jobs',
                            kind: BtnKind.dark,
                            onPressed: () => setState(() {
                                  _matching = false;
                                  _category = null;
                                  _nearby = false;
                                }))
                        : null,
                  )
                : PageList(
                    onRefresh: () => _view.currentState!.reload(),
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(plural(jobs.length, 'open job'), style: context.text.bodySmall)),
                      AutoGrid(minWidth: 340, gap: 12, maxColumns: 3, children: [for (final j in jobs) JobCard(j, forTechnician: true, onTap: () => openJob(context, j.id))]),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
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
