import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'job_widgets.dart';
import 'post_job_screen.dart';

/// The customer's jobs, filterable by where each one stands.
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Job>>>();
  String _filter = 'all';

  static const _filters = {'all': 'All', 'in_progress': 'In progress', 'pending': 'Getting quotes', 'completed': 'Completed', 'cancelled': 'Cancelled'};

  void _post() => push(context, const PostJobScreen(), path: '/post-job');

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'My jobs',
        subtitle: 'Everything you have posted, from first quote to final review.',
        actions: [Btn(context.isWide ? 'Post a job' : 'Post', icon: AppIcons.add, size: context.isWide ? BtnSize.md : BtnSize.sm, onPressed: _post)],
        body: AsyncView<List<Job>>(
          key: _view,
          load: () async => (await Api.list('/api/jobs', query: {'limit': 100})).map(Job.fromJson).toList(),
          events: Live.jobs,
          builder: (context, all) {
            final jobs = _filter == 'all' ? all : all.where((j) => j.status == _filter).toList();
            // Jobs that need the customer come first.
            jobs.sort((a, b) => (b.awaitingConfirmation ? 1 : 0) - (a.awaitingConfirmation ? 1 : 0));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PagePad(
                child: Pills<String>(
                  scroll: true,
                  values: _filters.keys.toList(),
                  label: (k) {
                    final n = k == 'all' ? all.length : all.where((j) => j.status == k).length;
                    return n == 0 ? _filters[k]! : '${_filters[k]} · $n';
                  },
                  selected: _filter,
                  onTap: (k) => setState(() => _filter = k),
                ),
              ),
              Expanded(
                child: jobs.isEmpty
                    ? EmptyState(
                        icon: AppIcons.jobs,
                        title: all.isEmpty ? 'No jobs yet' : 'Nothing here',
                        message: all.isEmpty ? 'Describe what needs fixing and get quotes from verified technicians.' : 'No jobs match this filter.',
                        action: all.isEmpty ? Btn('Post your first job', icon: AppIcons.add, onPressed: _post) : null,
                      )
                    : PageList(
                        onRefresh: () => _view.currentState!.reload(),
                        children: [
                          AutoGrid(minWidth: 340, gap: 12, maxColumns: 3, children: [for (final j in jobs) JobCard(j, onTap: () => openJob(context, j.id))]),
                        ],
                      ),
              ),
            ]);
          },
        ),
      );
}
