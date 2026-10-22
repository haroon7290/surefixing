import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/responsive.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import '../web/web_widgets.dart';
import 'my_rentals_screen.dart';
import 'tool_detail_screen.dart';

/// Tool rental marketplace (clients and technicians).
class ToolsMarketScreen extends StatefulWidget {
  const ToolsMarketScreen({super.key});

  @override
  State<ToolsMarketScreen> createState() => _ToolsMarketScreenState();
}

class _ToolsMarketScreenState extends State<ToolsMarketScreen> {
  final _search = TextEditingController();
  String? _category;
  String _sort = 'popular';
  bool _inStock = false;
  bool _installments = false;
  List<Tool>? _items;
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
      final res = await ApiClient.getList('/api/tools', query: {
        'q': _search.text.trim(),
        if (_category != null) 'category': _category!,
        if (_inStock) 'available': '1',
        if (_installments) 'installment': '1',
        'sort': _sort,
      });
      if (mounted) {
        setState(() {
          _items = res.map(Tool.fromJson).toList();
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
    'popular': 'Most rented',
    'price_asc': 'Price: low to high',
    'price_desc': 'Price: high to low',
    'rating': 'Top rated',
    'newest': 'Newest',
  };

  Future<void> _openTool(Tool t) async {
    await push(context, ToolDetailScreen(toolId: t.id));
    _load();
  }

  /// Website layout: filter sidebar + product grid.
  Widget _wide(BuildContext context) {
    final items = _items;
    final cat = _category == null ? null : Catalog.tool(_category);
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WebPageTitle(
          cat == null ? 'Rent tools' : cat.label,
          subtitle: items == null
              ? 'Loading tools…'
              : '${items.length} ${items.length == 1 ? 'tool' : 'tools'} from local suppliers · pay by the day',
          trailing: AuthService.instance.loggedIn
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => push(context, const MyRentalsScreen()),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('My rentals'),
                )
              : null,
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
                        const InputDecoration(hintText: 'Drill, ladder, washer…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
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
                    label: 'In stock now',
                    value: _inStock,
                    onChanged: (v) {
                      _inStock = v;
                      _changed();
                    },
                  ),
                  FilterSwitch(
                    label: 'Installment plans',
                    value: _installments,
                    onChanged: (v) {
                      _installments = v;
                      _changed();
                    },
                  ),
                  const FilterLabel('Category'),
                  FilterOption(
                    label: 'All tools',
                    icon: Icons.apps_rounded,
                    selected: _category == null,
                    onTap: () {
                      _category = null;
                      _changed();
                    },
                  ),
                  for (final c in Catalog.tools)
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
                          childAspectRatio: 0.9,
                          children: List.generate(6, (_) => const Skeleton(radius: 16, height: 280)),
                        ))
                  : items.isEmpty
                      ? const EmptyState(
                          icon: Icons.handyman_outlined, title: 'No tools match', message: 'Try another category or search term.')
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 40),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 290,
                            mainAxisExtent: 300,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => ToolCard(tool: items[i], onTap: () => _openTool(items[i])),
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
        title: const Text('Rent tools'),
        actions: [
          if (AuthService.instance.loggedIn)
            IconButton(
              tooltip: 'My rentals',
              onPressed: () => push(context, const MyRentalsScreen()),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (v) {
              _sort = v;
              _changed();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'popular', child: Text('Most rented')),
              PopupMenuItem(value: 'price_asc', child: Text('Price: low to high')),
              PopupMenuItem(value: 'price_desc', child: Text('Price: high to low')),
              PopupMenuItem(value: 'rating', child: Text('Top rated')),
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
                  hintText: 'Search drills, ladders, pressure washers…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('In stock'),
                  selected: _inStock,
                  onSelected: (v) {
                    _inStock = v;
                    _changed();
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Installments'),
                  selected: _installments,
                  onSelected: (v) {
                    _installments = v;
                    _changed();
                  },
                ),
                const SizedBox(width: 6),
                for (final c in Catalog.tools) ...[
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
                                icon: Icons.handyman_outlined, title: 'No tools match', message: 'Try another category or search term.'),
                          ])
                        : LayoutBuilder(
                            builder: (_, box) => GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: box.maxWidth > 900 ? 4 : (box.maxWidth > 600 ? 3 : 2),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: items.length,
                              itemBuilder: (_, i) => ToolCard(tool: items[i], onTap: () => _openTool(items[i])),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
