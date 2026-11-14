import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../location/location_picker.dart';
import 'tech_widgets.dart';

/// What the technician directory is narrowed to (the search text and the
/// sort live beside it).
class TechFilters {
  final String category;
  final double minRating;
  final bool verified;
  final bool available;
  final bool covers;
  final int radius;
  const TechFilters({this.category = '', this.minRating = 0, this.verified = false, this.available = false, this.covers = false, this.radius = 0});

  TechFilters copy({String? category, double? minRating, bool? verified, bool? available, bool? covers, int? radius}) => TechFilters(
        category: category ?? this.category,
        minRating: minRating ?? this.minRating,
        verified: verified ?? this.verified,
        available: available ?? this.available,
        covers: covers ?? this.covers,
        radius: radius ?? this.radius,
      );

  int get count => [category.isNotEmpty, minRating > 0, verified, available, covers, radius > 0].where((on) => on).length;

  String get key => '$category|$minRating|$verified|$available|$covers|$radius';
}

/// The technician directory: search, filter by distance, trade, rating and
/// more, and sort. Works signed out too (it is one of the public website's
/// pages).
class TechniciansScreen extends StatefulWidget {
  final String? category;
  const TechniciansScreen({super.key, this.category});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  late TechFilters _f = TechFilters(category: widget.category ?? SiteNav.presetCategory ?? '');
  String _query = '';
  String? _sort; // null = nearest when a location is known, else top rated
  Timer? _debounce;

  static const _sorts = {'distance': 'Nearest', 'rating': 'Top rated', 'jobs': 'Most jobs done', 'price': 'Lowest hourly rate', 'newest': 'Newest'};

  @override
  void initState() {
    super.initState();
    SiteNav.presetCategory = null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String get _effectiveSort {
    final known = Locations.instance.known;
    final s = _sort ?? (known ? 'distance' : 'rating');
    return s == 'distance' && !known ? 'rating' : s;
  }

  Map<String, String> get _sortOptions => Locations.instance.known ? _sorts : (Map.of(_sorts)..remove('distance'));

  Future<List<User>> _load(TechFilters f, String sort) async {
    final rows = await Api.list('/api/users/technicians', query: {
      'q': _query,
      'category': f.category,
      'verified': f.verified ? 1 : null,
      'available': f.available ? 1 : null,
      'minRating': f.minRating > 0 ? f.minRating : null,
      'covers': f.covers && Locations.instance.known ? 1 : null,
      'sort': sort,
      ...Locations.instance.query(),
      'limit': 60,
    });
    return rows.map(User.fromJson).toList();
  }

  void _apply(TechFilters f) {
    setState(() => _f = f);
    Locations.instance.setRadius(f.radius);
  }

  List<Widget> _groups(BuildContext context, TechFilters f, ValueChanged<TechFilters> set) {
    final known = Locations.instance.known;
    return [
      FilterGroup('Distance', child: DistanceFilter(radius: f.radius, onRadius: (km) => set(f.copy(radius: km)))),
      FilterGroup(
        'Show only',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FilterToggle(
            label: 'Travels to me',
            subtitle: known ? 'Within the distance they work' : 'Set your location first',
            icon: AppIcons.route,
            value: f.covers,
            onChanged: known ? (v) => set(f.copy(covers: v)) : null,
          ),
          FilterToggle(label: 'Verified ID', icon: AppIcons.shield, value: f.verified, onChanged: (v) => set(f.copy(verified: v))),
          FilterToggle(label: 'Available now', icon: AppIcons.bolt, value: f.available, onChanged: (v) => set(f.copy(available: v))),
        ]),
      ),
      FilterGroup(
        'Rating',
        child: Pills<double>(
          values: const [0, 3.5, 4, 4.5],
          label: (r) => r == 0 ? 'Any' : '${r.toStringAsFixed(1)}+',
          icon: (r) => r == 0 ? null : AppIcons.starFill,
          selected: f.minRating,
          onTap: (r) => set(f.copy(minRating: r)),
        ),
      ),
      FilterGroup(
        'Type of work',
        child: Pills<CatalogItem>(
          values: serviceCategories,
          label: (c) => c.label,
          selected: f.category.isEmpty ? null : serviceCategory(f.category),
          onTap: (c) => set(f.copy(category: f.category == c.key ? '' : c.key)),
        ),
      ),
    ];
  }

  Future<void> _openSheet(TechFilters f) async {
    final next = await showFilterSheet<TechFilters>(context, initial: f, cleared: const TechFilters(), groups: _groups);
    if (next != null) _apply(next);
  }

  String _summary(int n, String sort) {
    final loc = Locations.instance;
    final from = loc.searchFrom;
    final what = plural(n, 'technician');
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
          final sortMenu = SortMenu<String>(options: _sortOptions, value: sort, onChanged: (v) => setState(() => _sort = v));
          return AppPage(
            title: f.category.isEmpty ? 'Find technicians' : serviceCategory(f.category).label,
            subtitle: 'Verified professionals near you, with real reviews from completed jobs.',
            body: FilterLayout<List<User>>(
              token: '$_query|${f.key}|$sort|${from?.point.lat},${from?.point.lng}',
              load: () => _load(f, sort),
              search: SearchBox(
                hint: 'Search by name or skill',
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
                },
              ),
              panel: FilterPanel(active: f.count, onReset: () => _apply(const TechFilters()), children: _groups(context, f, _apply)),
              phoneBar: [
                const LocationChip(),
                BarButton('Filters', icon: AppIcons.filter, badge: f.count, onTap: () => _openSheet(f)),
                sortMenu,
              ],
              results: (context, techs) => techs.isEmpty
                  ? [
                      EmptyState(
                        icon: AppIcons.technicians,
                        title: 'No technicians match',
                        message: loc.radiusKm > 0 ? 'Nobody within ${loc.radiusKm} km. Try a wider distance or remove a filter.' : 'Try a different skill, or remove a filter.',
                        action: Btn(loc.radiusKm > 0 ? 'Search any distance' : 'Clear filters',
                            kind: BtnKind.dark, onPressed: () => _apply(loc.radiusKm > 0 ? f.copy(radius: 0) : const TechFilters())),
                      ),
                    ]
                  : [
                      ResultsHeader(_summary(techs.length, sort), sort: sortMenu),
                      AutoGrid(minWidth: 300, gap: 16, maxColumns: 3, children: [for (final t in techs) TechCard(t, onTap: () => openTechnician(context, t.id))]),
                    ],
            ),
          );
        },
      );
}
