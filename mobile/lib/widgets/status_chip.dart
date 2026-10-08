import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange,
      'in_progress': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.grey,
      'accepted': Colors.green,
      'rejected': Colors.red,
      'approved': Colors.green,
      'none': Colors.grey,
      'active': Colors.blue,
      'returned': Colors.grey,
    };
    final c = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
