import 'package:flutter/material.dart';

import 'features/account/kyc_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/jobs/job_detail_screen.dart';
import 'features/shell/shell.dart';
import 'features/technicians/technician_profile_screen.dart';
import 'features/tools/tool_detail_screen.dart';
import 'kit.dart';

/// Pages that have their own web address.
///   /jobs/<id>  /tools/<id>  /technicians/<id>
/// Returns null for anything else (sections are handled by `SiteNav`).
Widget? pageForPath(String route) {
  final segments = Uri.parse(route).pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2) return null;
  final id = segments[1];
  return switch (segments[0]) {
    'jobs' => Session.instance.loggedIn ? JobDetailScreen(jobId: id) : null,
    'tools' => ToolDetailScreen(toolId: id),
    'technicians' => TechnicianProfileScreen(technicianId: id),
    _ => null,
  };
}

void openJob(BuildContext context, String id) => push(context, JobDetailScreen(jobId: id), path: '/jobs/$id');

void openTool(BuildContext context, String id) => push(context, ToolDetailScreen(toolId: id), path: '/tools/$id');

void openTechnician(BuildContext context, String id) => push(context, TechnicianProfileScreen(technicianId: id), path: '/technicians/$id');

void openChat(BuildContext context, ChatTarget target) => push(context, ChatScreen(target: target));

/// Opens whatever a notification points at, for the signed-in role.
void openTarget(BuildContext context, {String? type, Json data = const {}}) {
  final role = Session.instance.role;
  final jobId = str(data['jobId']);
  final rentalId = str(data['rentalId']);
  final toolId = str(data['toolId']);
  if (jobId.isNotEmpty) {
    openJob(context, jobId);
  } else if (type == 'kyc') {
    role == 'admin' ? openSection(context, 'verify') : push(context, const KycScreen());
  } else if (rentalId.isNotEmpty) {
    openSection(context, role == 'supplier' ? 'orders' : 'rentals');
  } else if (toolId.isNotEmpty) {
    role == 'supplier' ? openSection(context, 'inventory') : openTool(context, toolId);
  } else if (type == 'report' && role == 'admin') {
    openSection(context, 'reports');
  } else if (type == 'wallet' || type == 'payment') {
    openSection(context, 'wallet');
  }
}
