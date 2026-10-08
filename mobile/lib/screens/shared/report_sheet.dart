import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';

/// Lets any user flag a person, job or tool for the admin team.
Future<void> showReportSheet(BuildContext context, {required String targetType, required String targetId, required String targetName}) {
  String reason = 'no_show';
  final details = TextEditingController();
  bool sending = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report $targetName', style: ctx.text.titleLarge),
            const SizedBox(height: 4),
            Text('Reports are private. Our team reviews every one.', style: TextStyle(color: ctx.palette.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in Catalog.reportReasons.entries)
                  ChoiceChip(label: Text(e.value), selected: reason == e.key, onSelected: (_) => setState(() => reason = e.key)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: details, maxLines: 3, decoration: const InputDecoration(hintText: 'What happened? (optional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ctx.palette.danger),
                onPressed: sending
                    ? null
                    : () async {
                        setState(() => sending = true);
                        try {
                          await ApiClient.post('/api/reports', {
                            'targetType': targetType,
                            'targetId': targetId,
                            'reason': reason,
                            'details': details.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          toast('Thanks — our team will review this report.', kind: ToastKind.success);
                        } catch (e) {
                          setState(() => sending = false);
                          toastError(e);
                        }
                      },
                child: const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
