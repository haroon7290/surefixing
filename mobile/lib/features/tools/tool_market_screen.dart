import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'tool_widgets.dart';

/// The tool market: rent by the day or buy in installments. Public.
class ToolMarketScreen extends StatefulWidget {
  const ToolMarketScreen({super.key});

  @override
  State<ToolMarketScreen> createState() => _ToolMarketScreenState();
}

class _ToolMarketScreenState extends State<ToolMarketScreen> {
  String _query = '';
  String? _category;
  bool _inStock = false;
  bool _installment = false;
  bool _nearby = false;
  String _sort = 'popular';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Tool>> _load() async {
    final rows = await Api.list('/api/tools', query: {
      'q': _query,
      'category': _category,
      'available': _inStock ? 1 : null,
      'installment': _installment ? 1 : null,
      'city': _nearby ? Session.instance.user?.city : null,
      'sort': _sort,
      'limit': 60,
    });
    return rows.map(Tool.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final city = Session.instance.user?.city ?? '';
    final wide = context.isWide;
    final token = '$_query|$_category|$_inStock|$_installment|$_nearby|$_sort';
    return AppPage(
      title: 'Rent tools',
      subtitle: 'Quality tools from local suppliers, by the day. Deposit refunded on return.',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Sort',
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'popular', child: Text('Most rented')),
            PopupMenuItem(value: 'rating', child: Text('Top rated')),
            PopupMenuItem(value: 'price_asc', child: Text('Price: low to high')),
            PopupMenuItem(value: 'price_desc', child: Text('Price: high to low')),
            PopupMenuItem(value: 'newest', child: Text('Newest')),
          ],
          child: const IgnorePointer(child: RoundBtn(AppIcons.sort, tooltip: 'Sort')),
        ),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: SearchBox(
            hint: 'Search tools: "drill", "ladder"…',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        PagePad(
          child: FilterBar(children: [
            Pills<bool>(values: const [true], label: (_) => 'In stock', selected: _inStock ? true : null, onTap: (_) => setState(() => _inStock = !_inStock)),
            Pills<bool>(
                values: const [true], label: (_) => 'Buy monthly', icon: (_) => AppIcons.calendar, selected: _installment ? true : null, onTap: (_) => setState(() => _installment = !_installment)),
            if (city.isNotEmpty) ...[
              Pills<bool>(values: const [true], label: (_) => 'In $city', icon: (_) => AppIcons.pin, selected: _nearby ? true : null, onTap: (_) => setState(() => _nearby = !_nearby)),
            ],
            Pills<CatalogItem>(
              values: toolCategories,
              label: (c) => c.label,
              icon: (c) => c.icon,
              selected: _category == null ? null : toolCategory(_category!),
              onTap: (c) => setState(() => _category = _category == c.key ? null : c.key),
            ),
          ]),
        ),
        Expanded(
          child: AsyncView<List<Tool>>(
            token: token,
            load: _load,
            builder: (context, tools) => tools.isEmpty
                ? EmptyState(
                    icon: AppIcons.tools,
                    title: 'No tools match',
                    message: 'Try another search, or remove a filter.',
                    action: Btn('Clear filters',
                        kind: BtnKind.dark,
                        onPressed: () => setState(() {
                              _category = null;
                              _inStock = _installment = _nearby = false;
                            })),
                  )
                : PageList(children: [
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(plural(tools.length, 'tool'), style: context.text.bodySmall)),
                    AutoGrid(
                      minWidth: wide ? 230 : 150,
                      gap: wide ? 16 : 12,
                      maxColumns: 5,
                      itemHeight: wide ? 300 : 248,
                      children: [for (final t in tools) ToolCard(t, onTap: () => openTool(context, t.id))],
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }
}
