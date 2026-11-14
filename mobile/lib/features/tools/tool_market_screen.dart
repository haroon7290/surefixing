import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../location/location_picker.dart';
import 'tool_widgets.dart';

/// Daily-rate bands offered in the price filter: (min, max), 0 = open.
const _priceBands = [(0, 0), (0, 500), (500, 1000), (1000, 0)];

String _bandLabel((int, int) b) => switch (b) {
      (0, 0) => 'Any price',
      (0, final max) => 'Up to ${money(max)}',
      (final min, 0) => '${money(min)}+',
      (final min, final max) => '${money(min)} – ${money(max).replaceFirst('Rs ', '')}',
    };

class ToolFilters {
  final String category;
  final int band; // index into _priceBands
  final bool inStock;
  final bool installment;
  final int radius;
  const ToolFilters({this.category = '', this.band = 0, this.inStock = false, this.installment = false, this.radius = 0});

  ToolFilters copy({String? category, int? band, bool? inStock, bool? installment, int? radius}) => ToolFilters(
        category: category ?? this.category,
        band: band ?? this.band,
        inStock: inStock ?? this.inStock,
        installment: installment ?? this.installment,
        radius: radius ?? this.radius,
      );

  int get count => [category.isNotEmpty, band > 0, inStock, installment, radius > 0].where((on) => on).length;
  String get key => '$category|$band|$inStock|$installment|$radius';
}

/// The tool market: rent by the day or buy in installments, from suppliers
/// near you. Public.
class ToolMarketScreen extends StatefulWidget {
  const ToolMarketScreen({super.key});

  @override
  State<ToolMarketScreen> createState() => _ToolMarketScreenState();
}

class _ToolMarketScreenState extends State<ToolMarketScreen> {
  ToolFilters _f = const ToolFilters();
  String _query = '';
  String? _sort; // null = nearest when a location is known, else most rented
  Timer? _debounce;

  static const _sorts = {
    'distance': 'Nearest',
    'popular': 'Most rented',
    'rating': 'Top rated',
    'price_asc': 'Price: low to high',
    'price_desc': 'Price: high to low',
    'newest': 'Newest',
  };

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String get _effectiveSort {
    final known = Locations.instance.known;
    final s = _sort ?? (known ? 'distance' : 'popular');
    return s == 'distance' && !known ? 'popular' : s;
  }

  Map<String, String> get _sortOptions => Locations.instance.known ? _sorts : (Map.of(_sorts)..remove('distance'));

  Future<List<Tool>> _load(ToolFilters f, String sort) async {
    final (min, max) = _priceBands[f.band];
    final rows = await Api.list('/api/tools', query: {
      'q': _query,
      'category': f.category,
      'available': f.inStock ? 1 : null,
      'installment': f.installment ? 1 : null,
      'minPrice': min > 0 ? min : null,
      'maxPrice': max > 0 ? max : null,
      'sort': sort,
      ...Locations.instance.query(),
      'limit': 60,
    });
    return rows.map(Tool.fromJson).toList();
  }

  void _apply(ToolFilters f) {
    setState(() => _f = f);
    Locations.instance.setRadius(f.radius);
  }

  List<Widget> _groups(BuildContext context, ToolFilters f, ValueChanged<ToolFilters> set) => [
        FilterGroup('Distance', hint: 'Tools are picked up from the supplier or delivered.', child: DistanceFilter(radius: f.radius, onRadius: (km) => set(f.copy(radius: km)))),
        FilterGroup(
          'Show only',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilterToggle(label: 'In stock now', icon: AppIcons.check, value: f.inStock, onChanged: (v) => set(f.copy(inStock: v))),
            FilterToggle(label: 'Buy monthly', subtitle: 'Can be bought in installments', icon: AppIcons.calendar, value: f.installment, onChanged: (v) => set(f.copy(installment: v))),
          ]),
        ),
        FilterGroup(
          'Price per day',
          child: Pills<int>(values: [for (var i = 0; i < _priceBands.length; i++) i], label: (i) => _bandLabel(_priceBands[i]), selected: f.band, onTap: (i) => set(f.copy(band: i))),
        ),
        FilterGroup(
          'Category',
          child: Pills<CatalogItem>(
            values: toolCategories,
            label: (c) => c.label,
            icon: (c) => c.icon,
            selected: f.category.isEmpty ? null : toolCategory(f.category),
            onTap: (c) => set(f.copy(category: f.category == c.key ? '' : c.key)),
          ),
        ),
      ];

  Future<void> _openSheet(ToolFilters f) async {
    final next = await showFilterSheet<ToolFilters>(context, initial: f, cleared: const ToolFilters(), groups: _groups);
    if (next != null) _apply(next);
  }

  String _summary(int n, String sort) {
    final loc = Locations.instance;
    final from = loc.searchFrom;
    final what = plural(n, 'tool');
    if (from == null) return what;
    if (loc.radiusKm > 0) return '$what within ${loc.radiusKm} km of ${from.label}';
    return sort == 'distance' ? '$what · nearest to ${from.label} first' : '$what · distances from ${from.label}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Locations.instance,
        builder: (context, _) {
          final loc = Locations.instance;
          final f = _f.copy(radius: loc.radiusKm);
          final sort = _effectiveSort;
          final from = loc.searchFrom;
          final wide = context.isWide;
          final sortMenu = SortMenu<String>(options: _sortOptions, value: sort, onChanged: (v) => setState(() => _sort = v));
          return AppPage(
            title: 'Rent tools',
            subtitle: 'Quality tools from suppliers near you, by the day. Deposit refunded on return.',
            body: FilterLayout<List<Tool>>(
              token: '$_query|${f.key}|$sort|${from?.point.lat},${from?.point.lng}',
              load: () => _load(f, sort),
              search: SearchBox(
                hint: 'Search tools: "drill", "ladder"…',
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
                },
              ),
              panel: FilterPanel(active: f.count, onReset: () => _apply(const ToolFilters()), children: _groups(context, f, _apply)),
              phoneBar: [
                const LocationChip(),
                BarButton('Filters', icon: AppIcons.filter, badge: f.count, onTap: () => _openSheet(f)),
                sortMenu,
              ],
              results: (context, tools) => tools.isEmpty
                  ? [
                      EmptyState(
                        icon: AppIcons.tools,
                        title: 'No tools match',
                        message: loc.radiusKm > 0 ? 'Nothing within ${loc.radiusKm} km. Try a wider distance or remove a filter.' : 'Try another search, or remove a filter.',
                        action: Btn(loc.radiusKm > 0 ? 'Search any distance' : 'Clear filters',
                            kind: BtnKind.dark, onPressed: () => _apply(loc.radiusKm > 0 ? f.copy(radius: 0) : const ToolFilters())),
                      ),
                    ]
                  : [
                      ResultsHeader(_summary(tools.length, sort), sort: sortMenu),
                      AutoGrid(
                        minWidth: wide ? 220 : 150,
                        gap: wide ? 16 : 12,
                        maxColumns: 4,
                        itemHeight: wide ? 300 : 248,
                        children: [for (final t in tools) ToolCard(t, onTap: () => openTool(context, t.id))],
                      ),
                    ],
            ),
          );
        },
      );
}
