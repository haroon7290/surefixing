import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/brand.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shells.dart';
import '../web/web_widgets.dart';
import 'admin_jobs.dart';

class AdminOverview extends StatefulWidget {
  const AdminOverview({super.key});

  @override
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> {
  Map<String, dynamic>? _s;
  Map<String, dynamic>? _ai;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ApiClient.getMap('/api/ai/status').then((v) {
      if (mounted) setState(() => _ai = v);
    }).catchError((_) {});
    try {
      final s = await ApiClient.getMap('/api/admin/stats');
      if (mounted) {
        setState(() {
          _s = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<MapEntry<String, num>> _series(String key) {
    final list = (_s?[key] as List? ?? []).whereType<Map>();
    return list.map((e) => MapEntry(DateFormat.E().format(DateTime.parse(e['date'].toString())), (e['count'] as num?) ?? 0)).toList();
  }

  List<MapEntry<String, num>> _map(String key, Map<String, String> labels) {
    final m = (_s?[key] as Map?) ?? {};
    return labels.entries.map((e) => MapEntry(e.value, (m[e.key] as num?) ?? 0)).toList();
  }

  List<Widget> _stats(BuildContext context, Map<String, dynamic> s) {
    final p = context.palette;
    return [
      StatTile(icon: Icons.group_rounded, value: Fmt.compact(s['users']), label: 'Users', onTap: () => HomeShell.goTo(context, 1)),
      StatTile(
          icon: Icons.work_rounded,
          value: Fmt.compact(s['jobs']),
          label: 'Jobs posted',
          color: p.warning,
          onTap: () => push(context, const AdminJobs())),
      StatTile(icon: Icons.payments_rounded, value: Fmt.compactMoney(s['jobsValue']), label: 'Completed job value', color: p.success),
      StatTile(icon: Icons.handyman_rounded, value: Fmt.compactMoney(s['rentalsValue']), label: 'Rental value', color: Brand.accent),
      StatTile(
          icon: Icons.verified_user_rounded,
          value: '${s['pendingKyc']}',
          label: 'KYC to review',
          color: p.info,
          onTap: () => HomeShell.goTo(context, 2)),
      StatTile(
          icon: Icons.flag_rounded,
          value: '${s['openReports']}',
          label: 'Open reports',
          color: p.danger,
          onTap: () => HomeShell.goTo(context, 3)),
      StatTile(
          icon: Icons.star_rounded,
          value: (s['avgTechnicianRating'] as num? ?? 0).toStringAsFixed(2),
          label: 'Avg technician rating',
          color: p.star),
      StatTile(icon: Icons.block_rounded, value: '${s['suspendedUsers'] ?? 0}', label: 'Suspended accounts', color: p.subtle),
    ];
  }

  List<Widget> _charts(BuildContext context, Map<String, dynamic> s) {
    final p = context.palette;
    return [
      _chartCard(context, 'New jobs · last 7 days', BarChart(data: _series('jobsLast7Days'), color: p.warning)),
      _chartCard(context, 'Sign-ups · last 7 days', BarChart(data: _series('signupsLast7Days'))),
      _chartCard(
        context,
        'Jobs by status',
        HBarList(
          data: _map('jobsByStatus', {'pending': 'Open', 'in_progress': 'In progress', 'completed': 'Completed', 'cancelled': 'Cancelled'}),
          colors: [p.info, p.warning, p.success, p.subtle],
        ),
      ),
      _chartCard(
        context,
        'Users by role',
        HBarList(
          data: _map('usersByRole', {'client': 'Clients', 'technician': 'Technicians', 'supplier': 'Suppliers', 'admin': 'Admins'}),
          colors: [context.colors.primary, p.success, Brand.accent, p.subtle],
        ),
      ),
      _chartCard(
        context,
        'Most requested services',
        HBarList(
          labelWidth: 120,
          data: [
            for (final c in (s['topCategories'] as List? ?? []).whereType<Map>())
              MapEntry(Catalog.service(c['category']?.toString()).label, (c['count'] as num?) ?? 0),
          ],
          colors: [for (final c in (s['topCategories'] as List? ?? []).whereType<Map>()) Catalog.service(c['category']?.toString()).color],
        ),
      ),
    ];
  }

  /// Website layout: four-column KPIs, charts in two columns.
  Widget _wide(BuildContext context, Map<String, dynamic> s) {
    final p = context.palette;
    final charts = _charts(context, s);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 56),
          child: WebContent(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              WebPageTitle(
                'Admin overview',
                subtitle: 'Marketplace health at a glance',
                trailing: _ai == null
                    ? null
                    : Pill(_ai!['online'] == true ? 'AI engine online' : 'AI fallback engine',
                        color: _ai!['online'] == true ? p.success : p.warning, icon: Icons.memory_rounded),
              ),
              ColumnsGrid(columns: 4, rowHeight: 130, children: _stats(context, s)),
              const SizedBox(height: 8),
              ColumnsGrid(columns: 2, children: charts),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final p = context.palette;
    if (s != null && context.isWide) return _wide(context, s);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [LogoMark(size: 30), SizedBox(width: 10), Text('Admin overview')]),
        actions: [
          if (_ai != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Pill(_ai!['online'] == true ? 'AI online' : 'AI fallback',
                  color: _ai!['online'] == true ? p.success : p.warning, icon: Icons.memory_rounded),
            ),
        ],
      ),
      body: s == null
          ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                    children: _stats(context, s),
                  ),
                  ..._charts(context, s),
                ],
              ),
            ),
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 14),
              child,
            ]),
          ),
        ),
      );
}
