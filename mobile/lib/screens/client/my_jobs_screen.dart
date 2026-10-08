import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import 'job_detail_client.dart';
import 'post_job_screen.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  List<Job>? _jobs;
  Object? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'job:bid', 'job:status', 'job:rated', 'job:hired'}).listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getList('/api/jobs', query: {'mine': '1', 'limit': '100'});
      if (mounted) {
        setState(() {
          _jobs = res.map(Job.fromJson).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Job j) async {
    await push(context, JobDetailClient(jobId: j.id));
    _load();
  }

  Future<void> _post() async {
    final created = await push<bool>(context, const PostJobScreen());
    if (created == true) _load();
  }

  Widget _list(List<Job> jobs, Widget empty) {
    return RefreshIndicator(
      onRefresh: _load,
      child: jobs.isEmpty
          ? ListView(children: [const SizedBox(height: 60), empty])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => JobCard(job: jobs[i], onTap: () => _open(jobs[i])),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _jobs ?? [];
    final active = jobs.where((j) => j.isActive).toList();
    final done = jobs.where((j) => j.status == 'completed').toList();
    final cancelled = jobs.where((j) => j.status == 'cancelled').toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My jobs'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active${_jobs == null ? '' : ' (${active.length})'}'),
              Tab(text: 'Completed${_jobs == null ? '' : ' (${done.length})'}'),
              const Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: _jobs == null
            ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
            : TabBarView(
                children: [
                  _list(
                    active,
                    EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No active jobs',
                      message: 'Post a job and verified technicians will send you quotes.',
                      actionLabel: 'Post a job',
                      onAction: _post,
                    ),
                  ),
                  _list(done, const EmptyState(icon: Icons.task_alt_rounded, title: 'Nothing completed yet')),
                  _list(cancelled, const EmptyState(icon: Icons.cancel_outlined, title: 'No cancelled jobs')),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'myjobs-post',
          onPressed: _post,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Post a job'),
        ),
      ),
    );
  }
}
