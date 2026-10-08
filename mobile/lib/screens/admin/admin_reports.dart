import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/async_list.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';

/// Trust & safety queue for user reports.
class AdminReports extends StatefulWidget {
  const AdminReports({super.key});

  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports> {
  final _updates = RealtimeService.instance.on({'report:new'});
  final _open = GlobalKey<AsyncListState<Map<String, dynamic>>>();
  final _closed = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  Future<void> _resolve(Map<String, dynamic> r, String status, {bool suspend = false}) async {
    final note = await promptDialog(
      context,
      title: status == 'dismissed' ? 'Dismiss report' : (suspend ? 'Resolve & suspend user' : 'Resolve report'),
      hint: 'Internal note (optional)',
      confirm: status == 'dismissed' ? 'Dismiss' : 'Resolve',
      destructive: suspend,
    );
    if (note == null) return;
    try {
      await ApiClient.post('/api/admin/reports/${r['_id']}/resolve', {'status': status, 'note': note, 'suspendUser': suspend});
      toast(suspend ? 'Resolved and user suspended' : 'Report $status', kind: ToastKind.success);
      _open.currentState?.reload();
      _closed.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  Widget _card(BuildContext context, Map<String, dynamic> r) {
    final reporter = Map<String, dynamic>.from(r['reporter'] ?? {});
    final isOpen = r['status'] == 'open';
    final icon = switch (r['targetType']) { 'user' => Icons.person_rounded, 'job' => Icons.work_rounded, _ => Icons.handyman_rounded };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.palette.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: context.palette.danger, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((r['targetLabel'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(Catalog.reportReasons[r['reason']] ?? '${r['reason']}',
                    style: TextStyle(color: context.palette.danger, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            StatusPill((r['status'] ?? '').toString()),
          ]),
          if ((r['details'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('“${r['details']}”', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            AppAvatar(name: (reporter['name'] ?? '?').toString(), url: (reporter['avatar'] ?? '').toString(), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Reported by ${reporter['name'] ?? 'someone'} · ${Fmt.ago(DateTime.tryParse('${r['createdAt']}'))}',
                  style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
            ),
          ]),
          if (!isOpen && (r['resolutionNote'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${r['resolutionNote']}', style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
          ],
          if (isOpen) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => _resolve(r, 'dismissed'),
                    child: const Text('Dismiss')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => _resolve(r, 'resolved'),
                    child: const Text('Resolve')),
              ),
              if (r['targetType'] == 'user') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: context.palette.danger),
                    onPressed: () => _resolve(r, 'resolved', suspend: true),
                    child: const Text('Suspend'),
                  ),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reports'), bottom: const TabBar(tabs: [Tab(text: 'Open'), Tab(text: 'Closed')])),
        body: TabBarView(children: [
          AsyncList<Map<String, dynamic>>(
            key: _open,
            load: () => ApiClient.getList('/api/admin/reports', query: {'status': 'open'}),
            reloadOn: _updates,
            empty: const EmptyState(icon: Icons.shield_moon_outlined, title: 'No open reports', message: 'The community is behaving 🙂'),
            itemBuilder: (c, r, _) => _card(c, r),
          ),
          AsyncList<Map<String, dynamic>>(
            key: _closed,
            load: () async {
              final res = await ApiClient.getList('/api/admin/reports');
              return res.where((r) => r['status'] != 'open').toList();
            },
            empty: const EmptyState(icon: Icons.history_rounded, title: 'Nothing closed yet'),
            itemBuilder: (c, r, _) => _card(c, r),
          ),
        ]),
      ),
    );
  }
}
