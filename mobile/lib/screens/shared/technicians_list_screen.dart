import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import '../web/web_widgets.dart';
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

  static const _sorts = {
    'rating': 'Top rated',
    'jobs': 'Most jobs completed',
    'price': 'Lowest hourly rate',
    'newest': 'Newest',
  };

  void _openProfile(User t) => push(context, TechnicianProfileScreen(technicianId: t.id));

  /// Website layout: filter sidebar + card grid.
  Widget _wide(BuildContext context) {
    final items = _items;
    final cat = _category == null ? null : Catalog.service(_category);
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WebPageTitle(
          cat == null ? 'Find a technician' : '${cat.label} technicians',
          subtitle: items == null
              ? 'Loading technicians…'
              : '${items.length} ${items.length == 1 ? 'technician' : 'technicians'} · sorted by ${_sorts[_sort]!.toLowerCase()}',
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 280,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: FilterPanel(children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 350), _load);
                    },
                    decoration:
                        const InputDecoration(hintText: 'Name or speciality', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                  ),
                  const FilterLabel('Sort by'),
                  DropdownButtonFormField<String>(
                    initialValue: _sort,
                    isDense: true,
                    items: [for (final e in _sorts.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) {
                      if (v == null) return;
                      _sort = v;
                      _changed();
                    },
                  ),
                  const SizedBox(height: 8),
                  FilterSwitch(
                    label: 'Available now',
                    value: _availableOnly,
                    onChanged: (v) {
                      _availableOnly = v;
                      _changed();
                    },
                  ),
                  FilterSwitch(
                    label: 'Verified only',
                    value: _verifiedOnly,
                    onChanged: (v) {
                      _verifiedOnly = v;
                      _changed();
                    },
                  ),
                  const FilterLabel('Service'),
                  FilterOption(
                    label: 'All services',
                    icon: Icons.apps_rounded,
                    selected: _category == null,
                    onTap: () {
                      _category = null;
                      _changed();
                    },
                  ),
                  for (final c in Catalog.services)
                    FilterOption(
                      label: c.label,
                      icon: c.icon,
                      color: c.color,
                      selected: _category == c.key,
                      onTap: () {
                        _category = c.key;
                        _changed();
                      },
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: items == null
                  ? (_error != null
                      ? ErrorView(message: _error.toString(), onRetry: _load)
                      : GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 1.05,
                          children: List.generate(6, (_) => const Skeleton(radius: 16, height: 240)),
                        ))
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_search_rounded,
                          title: 'No technicians found',
                          message: 'Try a different service or clear the filters.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 40),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisExtent: 262,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => WebTechCard(tech: items[i], onTap: () => _openProfile(items[i])),
                        ),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isWide) return _wide(context);
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
                            itemBuilder: (_, i) => TechnicianCard(tech: items[i], onTap: () => _openProfile(items[i])),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
