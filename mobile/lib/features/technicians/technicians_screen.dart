import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'tech_widgets.dart';

/// The technician directory: search, filter and sort. Works signed out
/// too (it is one of the public website's pages).
class TechniciansScreen extends StatefulWidget {
  final String? category;
  const TechniciansScreen({super.key, this.category});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  late String? _category = widget.category ?? SiteNav.presetCategory;
  String _query = '';
  bool _verified = false;
  bool _available = false;
  bool _nearby = false;
  String _sort = 'rating';
  Timer? _debounce;

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

  Future<List<User>> _load() async {
    final rows = await Api.list('/api/users/technicians', query: {
      'q': _query,
      'category': _category,
      'verified': _verified ? 1 : null,
      'available': _available ? 1 : null,
      'city': _nearby ? Session.instance.user?.city : null,
      'sort': _sort,
      'limit': 60,
    });
    return rows.map(User.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final city = Session.instance.user?.city ?? '';
    final token = '$_query|$_category|$_verified|$_available|$_nearby|$_sort';
    return AppPage(
      title: _category == null ? 'Find technicians' : serviceCategory(_category!).label,
      subtitle: 'Verified professionals with real reviews from completed jobs.',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Sort',
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rating', child: Text('Top rated')),
            PopupMenuItem(value: 'jobs', child: Text('Most jobs done')),
            PopupMenuItem(value: 'price', child: Text('Lowest hourly rate')),
            PopupMenuItem(value: 'newest', child: Text('Newest')),
          ],
          child: const IgnorePointer(child: RoundBtn(AppIcons.sort, tooltip: 'Sort')),
        ),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: SearchBox(
            hint: 'Search by name or skill',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        PagePad(
          child: SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              Pills<bool>(values: const [true], label: (_) => 'Verified', icon: (_) => AppIcons.shield, selected: _verified ? true : null, onTap: (_) => setState(() => _verified = !_verified)),
              Gap.w8,
              Pills<bool>(values: const [true], label: (_) => 'Available now', icon: (_) => AppIcons.bolt, selected: _available ? true : null, onTap: (_) => setState(() => _available = !_available)),
              Gap.w8,
              if (city.isNotEmpty) ...[
                Pills<bool>(values: const [true], label: (_) => 'In $city', icon: (_) => AppIcons.pin, selected: _nearby ? true : null, onTap: (_) => setState(() => _nearby = !_nearby)),
                Gap.w8,
              ],
              Pills<CatalogItem>(
                values: serviceCategories,
                label: (c) => c.label,
                selected: _category == null ? null : serviceCategory(_category!),
                onTap: (c) => setState(() => _category = _category == c.key ? null : c.key),
              ),
            ]),
          ),
        ),
        Expanded(
          child: AsyncView<List<User>>(
            token: token,
            load: _load,
            builder: (context, techs) => techs.isEmpty
                ? EmptyState(
                    icon: AppIcons.technicians,
                    title: 'No technicians match',
                    message: 'Try a different skill, or remove a filter.',
                    action: Btn('Clear filters', kind: BtnKind.dark, onPressed: () => setState(() {
                          _category = null;
                          _verified = _available = _nearby = false;
                        })),
                  )
                : PageList(children: [
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(plural(techs.length, 'technician'), style: context.text.bodySmall)),
                    AutoGrid(minWidth: 300, gap: 16, maxColumns: 3, children: [for (final t in techs) TechCard(t, onTap: () => openTechnician(context, t.id))]),
                  ]),
          ),
        ),
      ]),
    );
  }
}
