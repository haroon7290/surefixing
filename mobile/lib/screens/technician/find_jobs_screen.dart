import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import 'tech_job_detail.dart';

/// Open-job marketplace for technicians, with search and filters.
class FindJobsScreen extends StatefulWidget {
  const FindJobsScreen({super.key});

  @override
  State<FindJobsScreen> createState() => _FindJobsScreenState();
}

class _FindJobsScreenState extends State<FindJobsScreen> {
  final _search = TextEditingController();
  String? _category;
  String? _urgency;
  late bool _matching = AuthService.instance.user!.skills.isNotEmpty;
  bool _myCity = false;
  String _sort = 'newest';
  List<Job>? _items;
  Object? _error;
  Timer? _debounce;
  StreamSubscription? _sub;
  int _fresh = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'job:new'}).listen((_) {
      if (mounted) setState(() => _fresh++);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = AuthService.instance.user!;
    try {
      final res = await ApiClient.getList('/api/jobs', query: {
        'q': _search.text.trim(),
        if (_category != null) 'category': _category!,
        if (_urgency != null) 'urgency': _urgency!,
        if (_matching && _category == null) 'matching': '1',
        if (_myCity && me.city.isNotEmpty) 'city': me.city,
        'sort': _sort,
      });
      if (mounted) {
        setState(() {
          _items = res.map(Job.fromJson).toList();
          _error = null;
          _fresh = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _changed() {
    setState(() => _items = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user!;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find work'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) {
              _sort = v;
              _changed();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Newest first')),
              PopupMenuItem(value: 'budget', child: Text('Highest budget')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _load);
              },
              decoration: const InputDecoration(hintText: 'Search jobs', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (me.skills.isNotEmpty) ...[
                  FilterChip(
                    label: const Text('My skills'),
                    selected: _matching && _category == null,
                    onSelected: (v) {
                      _matching = v;
                      _category = null;
                      _changed();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (me.city.isNotEmpty) ...[
                  FilterChip(
                    label: Text('In ${me.city}'),
                    selected: _myCity,
                    onSelected: (v) {
                      _myCity = v;
                      _changed();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                for (final u in UrgencyInfo.all.reversed.take(2)) ...[
                  FilterChip(
                    avatar: Icon(u.icon, size: 16, color: u.color),
                    label: Text(u.label),
                    selected: _urgency == u.key,
                    onSelected: (v) {
                      _urgency = v ? u.key : null;
                      _changed();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                for (final c in Catalog.services) ...[
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    label: Text(c.label),
                    selected: _category == c.key,
                    showCheckmark: false,
                    onSelected: (v) {
                      _category = v ? c.key : null;
                      _changed();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (_fresh > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ActionChip(
                avatar: const Icon(Icons.arrow_upward_rounded, size: 16),
                label: Text('$_fresh new job${_fresh == 1 ? '' : 's'} — tap to refresh'),
                onPressed: _load,
              ),
            ),
          Expanded(
            child: items == null
                ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 60),
                            EmptyState(
                                icon: Icons.work_off_outlined,
                                title: 'No open jobs here',
                                message: 'Try clearing filters. New jobs are pushed to you live.'),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => JobCard(
                              job: items[i],
                              viewerId: me.id,
                              showClient: true,
                              onTap: () async {
                                await push(context, TechJobDetail(jobId: items[i].id));
                                _load();
                              },
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
