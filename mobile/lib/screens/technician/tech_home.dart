import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/job_thumbnail.dart';
import 'tech_job_detail.dart';

class TechHome extends StatefulWidget {
  const TechHome({super.key});

  @override
  State<TechHome> createState() => _TechHomeState();
}

class _TechHomeState extends State<TechHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _JobsList(key: ValueKey('open'), mine: false, title: 'Open jobs'),
      const _JobsList(key: ValueKey('mine'), mine: true, title: 'My work'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'Open jobs' : 'My work')),
      drawer: const AppDrawer(),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Open'),
          NavigationDestination(icon: Icon(Icons.handyman), label: 'My work'),
        ],
      ),
    );
  }
}

class _JobsList extends StatefulWidget {
  final bool mine;
  final String title;
  const _JobsList({super.key, required this.mine, required this.title});

  @override
  State<_JobsList> createState() => _JobsListState();
}

class _JobsListState extends State<_JobsList> {
  List<Job> _jobs = [];
  bool _loading = true;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((e) {
      // Open tab refreshes when a new job is broadcast; My-work tab refreshes
      // when the tech is hired or any of their assigned jobs change status.
      if (!widget.mine && e.name == 'job:new') {
        _load();
      } else if (widget.mine &&
          (e.name == 'job:hired' || e.name == 'job:status')) {
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
      final q = widget.mine ? {'mine': '1'} : <String, String>{};
      final res = await ApiClient.get('/api/jobs', query: q) as List;
      setState(() => _jobs = res.map((e) => Job.fromJson(Map<String, dynamic>.from(e))).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final meId = AuthService.instance.user!.id;
    return RefreshIndicator(
      onRefresh: _load,
      child: _jobs.isEmpty
          ? ListView(children: const [SizedBox(height: 200), Center(child: Text('Nothing here yet'))])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _jobs.length,
              itemBuilder: (_, i) {
                final j = _jobs[i];
                final iBid = j.bids.any((b) => b.technicianId == meId);
                return Card(
                  child: ListTile(
                    leading: JobThumbnail(images: j.images),
                    title: Row(children: [
                      Expanded(child: Text(j.title)),
                      if (iBid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('You bid',
                              style: TextStyle(color: Colors.indigo, fontSize: 11)),
                        ),
                    ]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          StatusChip(j.status),
                          const SizedBox(width: 8),
                          if (j.budget > 0) Text('Budget \$${j.budget.toStringAsFixed(0)}'),
                          const SizedBox(width: 8),
                          Text('${j.bids.length} bids'),
                        ]),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => TechJobDetail(jobId: j.id)));
                      _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}