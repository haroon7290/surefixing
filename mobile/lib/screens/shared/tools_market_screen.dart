import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
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

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent tools'),
        actions: [
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
                              itemBuilder: (_, i) => ToolCard(
                                tool: items[i],
                                onTap: () async {
                                  await push(context, ToolDetailScreen(toolId: items[i].id));
                                  _load();
                                },
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
