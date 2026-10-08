import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/theme.dart';

/// Small rounded label with a tinted background.
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  const Pill(this.label, {super.key, required this.color, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: context.isDark ? 0.2 : 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

/// Status pill for jobs, bids, rentals, KYC and reports.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (String label, Color color, IconData icon) = switch (status) {
      'pending' => ('Open', p.info, Icons.radio_button_checked),
      'in_progress' => ('In progress', p.warning, Icons.autorenew_rounded),
      'completed' => ('Completed', p.success, Icons.check_circle_rounded),
      'cancelled' => ('Cancelled', p.subtle, Icons.cancel_rounded),
      'accepted' => ('Accepted', p.success, Icons.check_circle_rounded),
      'rejected' => ('Declined', p.danger, Icons.cancel_rounded),
      'approved' => ('Verified', p.success, Icons.verified_rounded),
      'requested' => ('Requested', p.info, Icons.hourglass_top_rounded),
      'active' => ('Active', p.warning, Icons.timelapse_rounded),
      'returned' => ('Returned', p.success, Icons.assignment_turned_in_rounded),
      'open' => ('Open', p.danger, Icons.flag_rounded),
      'resolved' => ('Resolved', p.success, Icons.check_circle_rounded),
      'dismissed' => ('Dismissed', p.subtle, Icons.do_not_disturb_on_rounded),
      'suspended' => ('Suspended', p.danger, Icons.block_rounded),
      'none' => ('Not verified', p.subtle, Icons.shield_outlined),
      _ => (status.replaceAll('_', ' '), p.subtle, Icons.circle),
    };
    return Pill(label, color: color, icon: icon);
  }
}

class UrgencyPill extends StatelessWidget {
  final String urgency;
  final bool hideNormal;
  const UrgencyPill(this.urgency, {super.key, this.hideNormal = true});

  @override
  Widget build(BuildContext context) {
    if (hideNormal && (urgency == 'normal' || urgency.isEmpty)) return const SizedBox.shrink();
    final u = UrgencyInfo.of(urgency);
    return Pill(u.label, color: u.color, icon: u.icon, solid: urgency == 'emergency');
  }
}

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'ID verified',
        child: Icon(Icons.verified_rounded, size: size, color: context.palette.info),
      );
}

/// Rounded tile with a category icon on a tinted background.
class CategoryIcon extends StatelessWidget {
  final CategoryInfo info;
  final double size;
  const CategoryIcon(this.info, {super.key, this.size = 44});

  factory CategoryIcon.service(String key, {double size = 44}) => CategoryIcon(Catalog.service(key), size: size);
  factory CategoryIcon.tool(String key, {double size = 44}) => CategoryIcon(Catalog.tool(key), size: size);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: info.color.withValues(alpha: context.isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(info.icon, color: info.color, size: size * 0.52),
      );
}
