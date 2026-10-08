import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/navigation.dart';
import 'client/job_detail_client.dart';
import 'shared/kyc_screen.dart';
import 'shared/my_rentals_screen.dart';
import 'shared/tool_detail_screen.dart';
import 'supplier/rental_requests_screen.dart';
import 'supplier/tool_form_screen.dart';
import 'technician/tech_job_detail.dart';

/// Opens the screen a notification points at (job, rental, tool, KYC),
/// picking the right variant for the signed-in user's role.
void openTarget(BuildContext context, {String? type, Map<String, dynamic> data = const {}}) {
  final role = AuthService.instance.user?.role ?? 'client';
  final jobId = data['jobId']?.toString();
  final rentalId = data['rentalId']?.toString();
  final toolId = data['toolId']?.toString();

  if (jobId != null && jobId.isNotEmpty) {
    push(context, role == 'technician' ? TechJobDetail(jobId: jobId) : JobDetailClient(jobId: jobId));
  } else if (type == 'kyc') {
    push(context, const KycScreen());
  } else if (rentalId != null && rentalId.isNotEmpty) {
    push(context, role == 'supplier' ? const RentalRequestsScreen(standalone: true) : const MyRentalsScreen());
  } else if (toolId != null && toolId.isNotEmpty) {
    push(context, role == 'supplier' ? ToolFormScreen(toolId: toolId) : ToolDetailScreen(toolId: toolId));
  }
}
