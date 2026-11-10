import 'package:flutter/material.dart';

import '../../kit.dart';

/// "Report a problem" with a person, job or tool. Goes to the admin queue.
Future<void> showReportSheet(BuildContext context, {required String targetType, required String targetId, required String label, String? suggested}) async {
  var reason = suggested ?? '';
  final details = TextEditingController();
  var busy = false;
  await showAppSheet<void>(
    context,
    title: 'Report a problem',
    subtitle: 'About "$label". Our team reviews every report.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const FieldLabel('What is wrong?'),
        Pills<String>(values: reportReasons.keys.toList(), label: (k) => reportReasons[k]!, selected: reason.isEmpty ? null : reason, onTap: (k) => setState(() => reason = k)),
        Gap.h16,
        Field(label: 'Tell us what happened', hint: 'The more detail, the faster we can help.', controller: details, maxLines: 4, minLines: 3, maxLength: 1000, optional: true, capitalization: TextCapitalization.sentences),
        Gap.h8,
        Btn('Send report', size: BtnSize.lg, expand: true, loading: busy, onPressed: reason.isEmpty ? null : () async {
          setState(() => busy = true);
          try {
            await Api.post('/api/reports', {'targetType': targetType, 'targetId': targetId, 'reason': reason, 'details': details.text.trim()});
            toastOk('Report sent. We will let you know what we find.');
            if (context.mounted) Navigator.of(context).pop();
          } catch (e) {
            toastError(e);
            if (context.mounted) setState(() => busy = false);
          }
        }),
      ]),
    ),
  );
}
