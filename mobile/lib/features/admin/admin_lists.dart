import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../jobs/job_widgets.dart';
import '../wallet/wallet_screen.dart';

// ------------------------------------------------------------------- KYC

/// Identity documents waiting for a decision.
class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  final _view = GlobalKey<AsyncViewState<List<Kyc>>>();
  String _status = 'pending';

  Future<void> _decide(Kyc k, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await promptText(context, title: 'Reject ${k.user.name}\'s documents?', message: 'They can fix the problem and submit again.', label: 'What is wrong', hint: 'e.g. The ID photo is blurry', confirmLabel: 'Reject', danger: true, mandatory: true);
      if (reason == null) return;
    }
    try {
      await Api.post('/api/admin/kyc/${k.id}/verify', {'decision': approve ? 'approved' : 'rejected', if (reason != null) 'reason': reason});
      toastOk(approve ? '${k.user.name} is now verified' : 'Rejected — they were told why');
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Verification',
        subtitle: 'Check each ID against the selfie before giving the verified seal.',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PagePad(
            child: Pills<String>(
              scroll: true,
              values: const ['pending', 'approved', 'rejected'],
              label: (k) => const {'pending': 'Waiting', 'approved': 'Approved', 'rejected': 'Rejected'}[k]!,
              selected: _status,
              onTap: (k) => setState(() => _status = k),
            ),
          ),
          Expanded(
            child: AsyncView<List<Kyc>>(
              key: _view,
              token: _status,
              load: () async => (await Api.list('/api/admin/kyc', query: {'status': _status})).map(Kyc.fromJson).toList(),
              events: Live.admin,
              builder: (context, items) => items.isEmpty
                  ? EmptyState(icon: AppIcons.verify, title: _status == 'pending' ? 'Nothing to review' : 'None yet', message: _status == 'pending' ? 'New submissions appear here straight away.' : null)
                  : PageList(
                      onRefresh: () => _view.currentState!.reload(),
                      children: [
                        AutoGrid(minWidth: 380, gap: 16, maxColumns: 2, children: [
                          for (final k in items)
                            Panel(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                                PersonRow(
                                  name: k.user.name,
                                  image: k.user.avatar,
                                  subtitle: [roleLabels[k.user.role] ?? k.user.role, k.user.email].join('  ·  '),
                                  trailing: Pill.status(kycStatus(k.status)),
                                ),
                                Gap.h12,
                                KV('Legal name', k.fullName),
                                KV(idTypes[k.idType] ?? k.idType, k.idNumber),
                                KV('Submitted', dateTime(k.createdAt)),
                                Gap.h8,
                                Row(children: [
                                  for (final (label, file) in [('ID front', k.idFrontImage), ('ID back', k.idBackImage), ('Selfie', k.selfieImage)])
                                    if (file.isNotEmpty)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Semantics(
                                            button: true,
                                            label: 'View $label',
                                            excludeSemantics: true,
                                            child: GestureDetector(
                                              onTap: () => openGallery(context, [k.idFrontImage, k.idBackImage, k.selfieImage].where((f) => f.isNotEmpty).toList(),
                                                  [k.idFrontImage, k.idBackImage, k.selfieImage].where((f) => f.isNotEmpty).toList().indexOf(file)),
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                                ClipRRect(borderRadius: BorderRadius.circular(R.sm), child: AspectRatio(aspectRatio: 4 / 3, child: NetImage(file))),
                                                Gap.h4,
                                                Text(label, style: context.text.bodySmall),
                                              ]),
                                            ),
                                          ),
                                        ),
                                      ),
                                ]),
                                if (k.status == 'rejected' && k.rejectionReason.isNotEmpty) ...[Gap.h8, Notice(k.rejectionReason, tone: Tone.danger)],
                                if (k.status == 'pending') ...[
                                  Gap.h12,
                                  Row(children: [
                                    Expanded(child: Btn('Reject', kind: BtnKind.outline, expand: true, onPressed: () => _decide(k, false))),
                                    Gap.w8,
                                    Expanded(child: Btn('Approve', icon: AppIcons.check, expand: true, onPressed: () => _decide(k, true))),
                                  ]),
                                ],
                              ]),
                            ),
                        ]),
                      ],
                    ),
            ),
          ),
        ]),
      );
}

// --------------------------------------------------------------- reports

/// Trust & safety queue: what users flagged.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Report>>>();
  String _status = 'open';

  Future<void> _close(Report r, {required bool actionTaken, bool suspend = false}) async {
    final note = await promptText(
      context,
      title: suspend ? 'Suspend and resolve?' : (actionTaken ? 'Resolve this report?' : 'Dismiss this report?'),
      message: suspend ? 'The reported account is suspended and the reporter is told you took action.' : (actionTaken ? 'The reporter is told you took action.' : 'The reporter is told no violation was found.'),
      label: 'Internal note',
      confirmLabel: suspend ? 'Suspend & resolve' : (actionTaken ? 'Resolve' : 'Dismiss'),
      danger: suspend,
    );
    if (note == null) return;
    try {
      await Api.post('/api/admin/reports/${r.id}/resolve', {'status': actionTaken ? 'resolved' : 'dismissed', 'note': note, 'suspendUser': suspend});
      toastOk('Report closed');
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  void _openTarget(Report r) => switch (r.targetType) {
        'job' => openJob(context, r.targetId),
        'tool' => openTool(context, r.targetId),
        _ => openTechnician(context, r.targetId),
      };

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Reports',
        subtitle: 'Problems users flagged. Open the job to refund or release a disputed payment.',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PagePad(
            child: Pills<String>(
              scroll: true,
              values: const ['open', 'resolved', 'dismissed'],
              label: (k) => humanize(k),
              selected: _status,
              onTap: (k) => setState(() => _status = k),
            ),
          ),
          Expanded(
            child: AsyncView<List<Report>>(
              key: _view,
              token: _status,
              load: () async => (await Api.list('/api/admin/reports', query: {'status': _status})).map(Report.fromJson).toList(),
              events: Live.admin,
              builder: (context, items) => items.isEmpty
                  ? EmptyState(icon: AppIcons.reports, title: _status == 'open' ? 'No open reports' : 'None yet', message: _status == 'open' ? 'The queue is clear.' : null)
                  : PageList(
                      onRefresh: () => _view.currentState!.reload(),
                      children: [
                        AutoGrid(minWidth: 380, gap: 16, maxColumns: 2, children: [
                          for (final r in items)
                            Panel(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                                Row(children: [
                                  IconTile(switch (r.targetType) { 'job' => AppIcons.jobs, 'tool' => AppIcons.tools, _ => AppIcons.user }, tone: Tone.danger, size: 40),
                                  Gap.w12,
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                      Text(reportReasons[r.reason] ?? humanize(r.reason), style: context.text.titleMedium),
                                      Text('${humanize(r.targetType)}: ${r.targetLabel}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ]),
                                  ),
                                  Pill(humanize(r.status), tone: r.open ? Tone.warning : Tone.neutral, dot: true),
                                ]),
                                if (r.details.isNotEmpty) ...[Gap.h12, Text('"${r.details}"', style: context.text.bodyMedium)],
                                Gap.h12,
                                Row(children: [
                                  Avatar(name: r.reporter.name, image: r.reporter.avatar, size: 22),
                                  Gap.w8,
                                  Expanded(child: Text('Reported by ${r.reporter.name}  ·  ${timeAgo(r.createdAt)}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
                                if (!r.open && r.resolutionNote.isNotEmpty) ...[Gap.h8, Notice(r.resolutionNote, tone: Tone.neutral)],
                                Gap.h12,
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  Btn('Open ${r.targetType}', kind: BtnKind.dark, size: BtnSize.sm, trailing: AppIcons.arrowUpRight, onPressed: () => _openTarget(r)),
                                  if (r.open) ...[
                                    Btn('Resolve', icon: AppIcons.check, size: BtnSize.sm, onPressed: () => _close(r, actionTaken: true)),
                                    if (r.targetType == 'user') Btn('Suspend user', kind: BtnKind.danger, size: BtnSize.sm, onPressed: () => _close(r, actionTaken: true, suspend: true)),
                                    Btn('Dismiss', kind: BtnKind.outline, size: BtnSize.sm, onPressed: () => _close(r, actionTaken: false)),
                                  ],
                                ]),
                              ]),
                            ),
                        ]),
                      ],
                    ),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ jobs

/// Every job on the platform. Open one to resolve a dispute.
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  String _query = '';
  String _status = 'all';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Jobs',
        subtitle: 'Open a job to see its history, or to refund or release a disputed payment.',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PagePad(
            child: SearchBox(
              hint: 'Search jobs',
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
              },
            ),
          ),
          PagePad(
            child: Pills<String>(
              scroll: true,
              values: const ['all', 'pending', 'in_progress', 'completed', 'cancelled'],
              label: (k) => const {'all': 'All', 'pending': 'Getting quotes', 'in_progress': 'In progress', 'completed': 'Completed', 'cancelled': 'Cancelled'}[k]!,
              selected: _status,
              onTap: (k) => setState(() => _status = k),
            ),
          ),
          Expanded(
            child: AsyncView<List<Job>>(
              token: '$_query|$_status',
              load: () async => (await Api.list('/api/admin/jobs', query: {'q': _query, 'status': _status == 'all' ? null : _status, 'limit': 120})).map(Job.fromJson).toList(),
              events: Live.jobs,
              builder: (context, jobs) => jobs.isEmpty
                  ? const EmptyState(icon: AppIcons.jobs, title: 'No jobs match')
                  : PageList(children: [
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(plural(jobs.length, 'job'), style: context.text.bodySmall)),
                      AutoGrid(minWidth: 340, gap: 12, maxColumns: 3, children: [for (final j in jobs) JobCard(j, onTap: () => openJob(context, j.id))]),
                    ]),
            ),
          ),
        ]),
      );
}

// ----------------------------------------------------------------- tools

/// Every listed tool. Remove a listing that breaks the rules.
class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Tool>>>();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _remove(Tool t) async {
    if (!await confirm(context, title: 'Remove "${t.name}"?', message: 'The listing is deleted. Pending requests are cancelled and refunded.', confirmLabel: 'Remove listing', danger: true, icon: AppIcons.trash)) return;
    try {
      await Api.delete('/api/tools/${t.id}');
      toast('Listing removed');
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'Tools',
      subtitle: 'All tool listings across every supplier.',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: SearchBox(
            hint: 'Search tools',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
            },
          ),
        ),
        Expanded(
          child: AsyncView<List<Tool>>(
            key: _view,
            token: _query,
            load: () async => (await Api.list('/api/admin/tools', query: {'q': _query})).map(Tool.fromJson).toList(),
            builder: (context, tools) => tools.isEmpty
                ? const EmptyState(icon: AppIcons.tools, title: 'No tools match')
                : PageList(children: [
                    Panel(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < tools.length; i++) ...[
                          if (i > 0) Divider(indent: 84, color: c.line),
                          InkWell(
                            onTap: () => openTool(context, tools[i].id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(R.sm),
                                  child: SizedBox.square(dimension: 56, child: CoverImage(tools[i].image, category: toolCategory(tools[i].category), iconSize: 24)),
                                ),
                                Gap.w12,
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    Text(tools[i].name, style: context.text.titleSmall!.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('${tools[i].supplier.name}  ·  ${money(tools[i].rentPricePerDay)} /day  ·  ${tools[i].stock} in stock', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ]),
                                ),
                                if (!tools[i].available) const Padding(padding: EdgeInsets.only(right: 8), child: Pill('Hidden')),
                                IconButton(tooltip: 'Remove listing', onPressed: () => _remove(tools[i]), icon: Icon(AppIcons.trash, size: 18, color: c.danger)),
                              ]),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// -------------------------------------------------------------- payments

/// Every wallet movement on the platform.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String _type = 'all';

  static const _types = {
    'all': 'Everything',
    'platform_fee': 'Fees earned',
    'job_hold': 'Into escrow',
    'job_earning': 'Paid to technicians',
    'job_refund': 'Refunds',
    'rental_earning': 'Rental income',
    'topup': 'Top-ups',
    'withdrawal': 'Withdrawals',
  };

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Payments',
        subtitle: 'The full ledger: escrow holds, payouts, refunds and SureFix fees.',
        maxWidth: 900,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PagePad(child: Pills<String>(scroll: true, values: _types.keys.toList(), label: (k) => _types[k]!, selected: _type, onTap: (k) => setState(() => _type = k))),
          Expanded(
            child: AsyncView<List<Txn>>(
              token: _type,
              load: () async => (await Api.list('/api/admin/transactions', query: {'type': _type == 'all' ? null : _type, 'limit': 150})).map(Txn.fromJson).toList(),
              events: Live.wallet,
              builder: (context, items) => items.isEmpty
                  ? const EmptyState(icon: AppIcons.payments, title: 'No transactions yet')
                  : PageList(children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${plural(items.length, 'movement')}  ·  net ${signedMoney(items.fold<double>(0, (a, t) => a + t.amount))}', style: context.text.bodySmall),
                      ),
                      TxnList(items, showUser: true),
                    ]),
            ),
          ),
        ]),
      );
}
