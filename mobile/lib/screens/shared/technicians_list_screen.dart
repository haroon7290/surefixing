import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import 'technician_profile_screen.dart';

/// Browsable, filterable technician directory.
class TechniciansListScreen extends StatefulWidget {
  final String? category;
  const TechniciansListScreen({super.key, this.category});

  @override
  State<TechniciansListScreen> createState() => _TechniciansListScreenState();
}

class _TechniciansListScreenState extends State<TechniciansListScreen> {
  final _search = TextEditingController();
  late String? _category = widget.category;
  bool _availableOnly = false;
  bool _verifiedOnly = false;
  String _sort = 'rating';
  List<User>? _items;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getList('/api/users/technicians', query: {
        'q': _search.text.trim(),
        if (_category != null) 'category': _category!,
        if (_availableOnly) 'available': '1',
        if (_verifiedOnly) 'verified': '1',
        'sort': _sort,
      });
      if (mounted) {
        setState(() {
          _items = res.map(User.fromJson).toList();
          _error = null;
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
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Text(_category == null ? 'Technicians' : Catalog.service(_category).label),
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
              PopupMenuItem(value: 'rating', child: Text('Top rated')),
              PopupMenuItem(value: 'jobs', child: Text('Most jobs completed')),
              PopupMenuItem(value: 'price', child: Text('Lowest hourly rate')),
              PopupMenuItem(value: 'newest', child: Text('Newest')),
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
              decoration: const InputDecoration(
                  hintText: 'Search name, skill or speciality', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Available now'),
                  selected: _availableOnly,
                  onSelected: (v) {
                    _availableOnly = v;
                    _changed();
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: Icon(Icons.verified_rounded, size: 16, color: context.palette.info),
                  label: const Text('Verified'),
                  selected: _verifiedOnly,
                  onSelected: (v) {
                    _verifiedOnly = v;
                    _changed();
                  },
                ),
                const SizedBox(width: 6),
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
          Expanded(
            child: items == null
                ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 60),
                            EmptyState(
                                icon: Icons.person_search_rounded,
                                title: 'No technicians found',
                                message: 'Try a different category or clear the filters.'),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => TechnicianCard(
                              tech: items[i],
                              onTap: () => push(context, TechnicianProfileScreen(technicianId: items[i].id)),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
