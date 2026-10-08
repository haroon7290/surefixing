import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import 'tech_job_detail.dart';

/// Technician's pipeline: direct requests, open quotes, active and done.
class MyWorkScreen extends StatefulWidget {
  const MyWorkScreen({super.key});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  final _updates = RealtimeService.instance.on({'job:request', 'job:hired', 'job:status', 'job:rated'});
  final _keys = List.generate(4, (_) => GlobalKey<AsyncListState<Job>>());

  Future<List<Job>> _get(Map<String, String> q) async => (await ApiClient.getList('/api/jobs', query: q)).map(Job.fromJson).toList();

  Widget _tab(int i, Future<List<Job>> Function() load, Widget empty) {
    final me = AuthService.instance.user!.id;
    return AsyncList<Job>(
      key: _keys[i],
      load: load,
      reloadOn: _updates,
      empty: empty,
      itemBuilder: (context, j, _) => JobCard(
        job: j,
        viewerId: me,
        showClient: true,
        onTap: () async {
          await push(context, TechJobDetail(jobId: j.id));
          for (final k in _keys) {
            k.currentState?.reload();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My jobs'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [Tab(text: 'Requests'), Tab(text: 'Quoted'), Tab(text: 'Active'), Tab(text: 'Completed')],
          ),
        ),
        body: TabBarView(children: [
          _tab(
              0,
              () => _get({'view': 'requests'}),
              const EmptyState(
                  icon: Icons.person_pin_outlined,
                  title: 'No direct requests',
                  message: 'When a client requests you specifically, it shows up here.')),
          _tab(
              1,
              () => _get({'view': 'bids', 'status': 'pending'}),
              const EmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'No open quotes',
                  message: 'Quote on jobs from Find work — they\'ll be tracked here.')),
          _tab(2, () => _get({'mine': '1', 'status': 'in_progress'}),
              const EmptyState(icon: Icons.handyman_outlined, title: 'No active jobs', message: 'Jobs you\'re hired for appear here.')),
          _tab(3, () => _get({'mine': '1', 'status': 'completed'}),
              const EmptyState(icon: Icons.task_alt_rounded, title: 'No completed jobs yet')),
        ]),
      ),
    );
  }
}
