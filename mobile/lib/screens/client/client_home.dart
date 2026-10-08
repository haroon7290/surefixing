import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/job_thumbnail.dart';
import '../shared/tools_list_screen.dart';
import '../shared/technicians_list_screen.dart';
import 'post_job_screen.dart';
import 'job_detail_client.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _tab = 0;
  int _jobsRefreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _MyJobsTab(key: ValueKey(_jobsRefreshKey)),
      const ToolsListScreen(),
      const TechniciansListScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['My jobs', 'Rent / Buy tools', 'Technicians'][_tab]),
      ),
      drawer: const AppDrawer(),
      body: tabs[_tab],
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const PostJobScreen()),
                );
                if (created == true && mounted) setState(() => _jobsRefreshKey++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Post job'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.build), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.hardware), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.engineering), label: 'Technicians'),
        ],
      ),
    );
  }
}

class _MyJobsTab extends StatefulWidget {
  const _MyJobsTab({super.key});

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> {
  List<Job> _jobs = [];
  bool _loading = true;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((e) {
      // Anything that mutates one of this client's jobs → refresh the list.
      if (e.name == 'job:bid' || e.name == 'job:status' || e.name == 'job:rated') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/jobs', query: {'mine': '1'}) as List;
      setState(() => _jobs = res.map((e) => Job.fromJson(Map<String, dynamic>.from(e))).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _jobs.isEmpty
          ? ListView(children: const [
              SizedBox(height: 200),
              Center(child: Text('No jobs yet. Tap "Post job" to create one.')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _jobs.length,
              itemBuilder: (_, i) {
                final j = _jobs[i];
                return Card(
                  child: ListTile(
                    leading: JobThumbnail(images: j.images),
                    title: Text(j.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          StatusChip(j.status),
                          const SizedBox(width: 8),
                          Text('${j.bids.length} bids'),
                          if (j.budget > 0) ...[
                            const SizedBox(width: 8),
                            Text('Budget \$${j.budget.toStringAsFixed(0)}'),
                          ],
                        ]),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => JobDetailClient(jobId: j.id)));
                      _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}