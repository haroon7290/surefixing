import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/async_list.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/states.dart';

/// Admin KYC review queue.
class AdminKyc extends StatefulWidget {
  const AdminKyc({super.key});

  @override
  State<AdminKyc> createState() => _AdminKycState();
}

class _AdminKycState extends State<AdminKyc> {
  final _updates = RealtimeService.instance.on({'kyc:new'});
  final _keys = List.generate(3, (_) => GlobalKey<AsyncListState<Map<String, dynamic>>>());

  Future<void> _decide(Map<String, dynamic> k, String decision) async {
    String? reason;
    if (decision == 'rejected') {
      reason = await promptDialog(context,
          title: 'Reject verification',
          message: 'Tell the user what to fix.',
          hint: 'e.g. ID photo is blurry',
          confirm: 'Reject',
          required: true,
          destructive: true);
      if (reason == null) return;
    }
    try {
      await ApiClient.post('/api/admin/kyc/${k['_id']}/verify', {'decision': decision, if (reason != null) 'reason': reason});
      toast(decision == 'approved' ? 'Verified ✓' : 'Rejected', kind: ToastKind.success);
      for (final key in _keys) {
        key.currentState?.reload();
      }
    } catch (e) {
      toastError(e);
    }
  }

  Widget _card(BuildContext context, Map<String, dynamic> k) {
    final u = Map<String, dynamic>.from(k['user'] ?? {});
    final docs = [
      ('ID front', (k['idFrontImage'] ?? '').toString()),
      ('ID back', (k['idBackImage'] ?? '').toString()),
      ('Selfie', (k['selfieImage'] ?? '').toString()),
    ];
    final images = docs.map((d) => d.$2).where((s) => s.isNotEmpty).toList();
    final idType = switch (k['idType']) { 'cnic' => 'CNIC', 'passport' => 'Passport', 'driver_license' => 'Driving licence', _ => 'ID' };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AppAvatar(name: (u['name'] ?? '?').toString(), url: (u['avatar'] ?? '').toString(), size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((k['fullName'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('${u['name'] ?? ''} · ${Fmt.titleCase((u['role'] ?? '').toString())}',
                    style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
              ]),
            ),
            StatusPill(k['status'] == 'pending' ? 'requested' : (k['status'] ?? '').toString()),
          ]),
          const SizedBox(height: 10),
          Text('$idType · ${k['idNumber']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('Submitted ${Fmt.ago(DateTime.tryParse('${k['createdAt']}'))}',
              style: TextStyle(color: context.palette.subtle, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: docs[i].$2.isEmpty ? null : () => PhotoViewer.open(context, images, images.indexOf(docs[i].$2)),
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 78,
                        width: double.infinity,
                        child: docs[i].$2.isEmpty
                            ? Container(
                                color: context.palette.fill, child: Icon(Icons.no_photography_outlined, color: context.palette.subtle))
                            : NetImage(docs[i].$2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(docs[i].$1, style: TextStyle(fontSize: 11, color: context.palette.muted)),
                  ]),
                ),
              ),
            ],
          ]),
          if ((k['rejectionReason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reason: ${k['rejectionReason']}', style: TextStyle(color: context.palette.danger, fontSize: 13)),
          ],
          if (k['status'] == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      onPressed: () => _decide(k, 'rejected'),
                      child: const Text('Reject'))),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: context.palette.success),
                  onPressed: () => _decide(k, 'approved'),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _tab(int i, String status, String emptyTitle) => AsyncList<Map<String, dynamic>>(
        key: _keys[i],
        load: () => ApiClient.getList('/api/admin/kyc', query: {'status': status}),
        reloadOn: _updates,
        empty: EmptyState(icon: Icons.verified_user_outlined, title: emptyTitle),
        itemBuilder: (c, k, _) => _card(c, k),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identity verification'),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Rejected')]),
        ),
        body: TabBarView(children: [
          _tab(0, 'pending', 'Queue is clear 🎉'),
          _tab(1, 'approved', 'No approvals yet'),
          _tab(2, 'rejected', 'No rejections'),
        ]),
      ),
    );
  }
}
