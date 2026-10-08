import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/async_list.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import '../client/job_detail_client.dart';

/// Every job on the platform, filterable by status (admin).
class AdminJobs extends StatefulWidget {
  const AdminJobs({super.key});

  @override
  State<AdminJobs> createState() => _AdminJobsState();
}

class _AdminJobsState extends State<AdminJobs> {
  String _status = '';
  final _list = GlobalKey<AsyncListState<Job>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All jobs')),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), children: [
            for (final s in const [
              ('', 'All'),
              ('pending', 'Open'),
              ('in_progress', 'In progress'),
              ('completed', 'Completed'),
              ('cancelled', 'Cancelled')
            ]) ...[
              ChoiceChip(
                label: Text(s.$2),
                selected: _status == s.$1,
                onSelected: (_) {
                  setState(() => _status = s.$1);
                  _list.currentState?.reload();
                },
              ),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        Expanded(
          child: AsyncList<Job>(
            key: _list,
            load: () async => (await ApiClient.getList('/api/admin/jobs', query: {'status': _status})).map(Job.fromJson).toList(),
            empty: const EmptyState(icon: Icons.work_off_outlined, title: 'No jobs'),
            itemBuilder: (c, j, _) => JobCard(job: j, showClient: true, onTap: () => push(c, JobDetailClient(jobId: j.id))),
          ),
        ),
      ]),
    );
  }
}
