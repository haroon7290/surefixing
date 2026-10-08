import 'package:flutter/material.dart';

import '../../models/rental.dart';
import '../../services/api_client.dart';
import '../../services/navigation.dart';
import '../../widgets/dialogs.dart';

/// Supplier action buttons for a rental, based on its status.
List<Widget> rentalActions(BuildContext context, Rental r, VoidCallback onDone) {
  Future<void> call(String path, String success, [Map<String, dynamic>? body]) async {
    try {
      await ApiClient.post('/api/rentals/${r.id}/$path', body);
      toast(success, kind: ToastKind.success);
      onDone();
    } catch (e) {
      toastError(e);
    }
  }

  const size = Size(0, 40);
  switch (r.status) {
    case 'requested':
      return [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: size),
          onPressed: () async {
            final reason = await promptDialog(context,
                title: 'Decline request?', hint: 'Reason for the customer (optional)', confirm: 'Decline', destructive: true);
            if (reason != null) await call('reject', 'Request declined', {'reason': reason});
          },
          child: const Text('Decline'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: size),
          onPressed: () => call('approve', r.isInstallment ? 'Installment plan approved' : 'Rental approved — stock reserved'),
          child: const Text('Approve'),
        ),
      ];
    case 'active':
      return [
        FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: size),
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: r.isInstallment ? 'Mark plan as fully paid?' : 'Mark as returned?',
              message: r.isInstallment
                  ? 'This closes the installment plan.'
                  : 'The tool goes back into stock and the customer is asked for a review.',
              confirm: r.isInstallment ? 'Fully paid' : 'Returned',
            );
            if (ok) await call(r.isInstallment ? 'complete' : 'return', r.isInstallment ? 'Plan completed' : 'Marked as returned');
          },
          child: Text(r.isInstallment ? 'Mark fully paid' : 'Mark returned'),
        ),
      ];
    default:
      return const [];
  }
}
