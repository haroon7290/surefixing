import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../client/job_detail_client.dart' show jobTimeline;
import '../shared/chat_screen.dart';
import '../shared/report_sheet.dart';

class TechJobDetail extends StatefulWidget {
  final String jobId;
  const TechJobDetail({super.key, required this.jobId});

  @override
  State<TechJobDetail> createState() => _TechJobDetailState();
}

class _TechJobDetailState extends State<TechJobDetail> {
  Job? _job;
  Object? _error;
  bool _busy = false;
  StreamSubscription? _sub;

  String get _me => AuthService.instance.user!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _sub =
        RealtimeService.instance.on({'job:status', 'job:hired', 'job:rated'}).where((e) => e.jobId == widget.jobId).listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final j = Job.fromJson(await ApiClient.getMap('/api/jobs/${widget.jobId}'));
      if (mounted) {
        setState(() {
          _job = j;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      toast(success, kind: ToastKind.success);
      await _load();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quote() async {
    final sent = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _QuoteSheet(job: _job!));
    if (sent == true) {
      toast('Quote sent to ${_job!.client.name.split(' ').first}', kind: ToastKind.success);
      _load();
    }
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(context,
        title: 'Withdraw your quote?', message: 'You can quote again while the job is still open.', confirm: 'Withdraw', destructive: true);
    if (ok) await _run(() => ApiClient.delete('/api/jobs/${widget.jobId}/bids/me'), 'Quote withdrawn');
  }

  Future<void> _decline() async {
    final reason = await promptDialog(context,
        title: 'Decline this request?',
        message: 'The client can then open it to other technicians.',
        hint: 'Reason (optional)',
        confirm: 'Decline',
        destructive: true);
    if (reason != null) await _run(() => ApiClient.post('/api/jobs/${widget.jobId}/decline', {'reason': reason}), 'Request declined');
  }

  Future<void> _complete() async {
    final ok = await confirmDialog(context,
        title: 'Mark job as completed?', message: 'The client will be asked to review your work.', confirm: 'Mark completed');
    if (ok) await _run(() => ApiClient.patch('/api/jobs/${widget.jobId}/status', {'status': 'completed'}), 'Nice work! Job completed 🎉');
  }

  void _chat() => push(
      context,
      ChatScreen(
          jobId: widget.jobId,
          otherId: _job!.client.id,
          otherName: _job!.client.name,
          otherAvatar: _job!.client.avatar,
          jobTitle: _job!.title));

  @override
  Widget build(BuildContext context) {
    final j = _job;
    if (j == null) {
      return Scaffold(
          appBar: AppBar(), body: _error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList(count: 4));
    }
    final cat = Catalog.service(j.category);
    final myBid = j.bidBy(_me);
    final assignedToMe = j.technicianId == _me;
    final requestedMe = j.requestedTechnician?.id == _me;
    final lostIt = j.technician != null && !assignedToMe;
    final canQuote = j.isOpen && myBid == null && (!j.isDirectRequest || (requestedMe && !j.requestDeclined));
    final canChat = !lostIt && j.status != 'cancelled' && (assignedToMe || myBid != null || requestedMe);
    final others = j.bids.where((b) => b.technicianId != _me).toList();
    final p = context.palette;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: j.images.isNotEmpty ? 220 : 0,
            title: Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (canChat) IconButton(tooltip: 'Chat with client', onPressed: _chat, icon: const Icon(Icons.chat_bubble_outline_rounded)),
              PopupMenuButton<String>(
                onSelected: (_) => showReportSheet(context, targetType: 'job', targetId: j.id, targetName: 'this job'),
                itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report job'))],
              ),
            ],
            flexibleSpace: j.images.isEmpty
                ? null
                : FlexibleSpaceBar(
                    background: GestureDetector(
                        onTap: () => PhotoViewer.open(context, j.images), child: NetImage(j.images.first, placeholder: cat)),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList.list(children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CategoryIcon(cat, size: 40),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${cat.label} · ${Fmt.ago(j.createdAt)}', style: TextStyle(color: p.muted, fontSize: 13))),
                      Text(j.budget > 0 ? Fmt.money(j.budget) : 'Open budget',
                          style: context.text.titleMedium?.copyWith(color: context.colors.primary)),
                    ]),
                    const SizedBox(height: 12),
                    Text(j.title, style: context.text.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusPill(lostIt ? 'cancelled' : j.status),
                      UrgencyPill(j.urgency, hideNormal: false),
                      if (requestedMe && j.isOpen)
                        Pill(j.requestDeclined ? 'You declined' : 'Requested you',
                            color: const Color(0xFF7A5AF8), icon: Icons.person_pin_rounded),
                    ]),
                    if (lostIt) ...[
                      const SizedBox(height: 10),
                      Text('This job was assigned to another technician.', style: TextStyle(color: p.muted)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    AppAvatar(name: j.client.name, url: j.client.avatar, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Client', style: TextStyle(color: p.muted, fontSize: 12.5)),
                        Text(j.client.name, style: context.text.titleSmall?.copyWith(fontSize: 15)),
                        if ((j.client.phone ?? '').isNotEmpty)
                          SelectableText(j.client.phone!, style: TextStyle(color: p.success, fontWeight: FontWeight.w700))
                        else if (j.client.city.isNotEmpty)
                          Text(j.client.city, style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ]),
                    ),
                    if (canChat)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: _chat,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text('Chat'),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Job details', style: context.text.titleSmall),
                    const SizedBox(height: 8),
                    Text(j.description),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    if (j.preferredDate != null)
                      InfoRow(icon: Icons.event_outlined, label: 'Preferred date', value: Fmt.weekday(j.preferredDate)),
                    if (j.city.isNotEmpty) InfoRow(icon: Icons.location_city_outlined, label: 'City', value: j.city),
                    InfoRow(
                      icon: Icons.home_outlined,
                      label: 'Address',
                      value: assignedToMe ? (j.location.isEmpty ? '—' : j.location) : 'Shared after you\'re hired',
                      valueColor: assignedToMe ? null : p.subtle,
                    ),
                    if (j.agreedPrice != null && assignedToMe)
                      InfoRow(
                          icon: Icons.handshake_outlined, label: 'Agreed price', value: Fmt.money(j.agreedPrice), valueColor: p.success),
                    if (j.images.length > 1) ...[const SizedBox(height: 10), PhotoStrip(images: j.images, size: 84)],
                  ]),
                ),
              ),
              if (myBid != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: context.colors.primary.withValues(alpha: context.isDark ? 0.14 : 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Your quote', style: context.text.titleSmall),
                        const Spacer(),
                        StatusPill(myBid.status),
                      ]),
                      const SizedBox(height: 8),
                      Text(Fmt.money(myBid.amount),
                          style: context.text.headlineSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800)),
                      Text(myBid.etaDays == 0 ? 'Can start today' : 'Ready in ${Fmt.plural(myBid.etaDays, 'day')}',
                          style: TextStyle(color: p.muted)),
                      if (myBid.message.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('“${myBid.message}”', style: const TextStyle(fontStyle: FontStyle.italic))
                      ],
                      if (myBid.status == 'pending' && j.isOpen) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: p.danger),
                            onPressed: _busy ? null : _withdraw,
                            icon: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Withdraw quote'),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
              if (j.isOpen && others.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.groups_2_outlined, color: p.muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${Fmt.plural(others.length, 'other quote')} · lowest ${Fmt.money(others.map((b) => b.amount).reduce((a, b) => a < b ? a : b))}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
              if (j.rating != null && assignedToMe) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Client review', style: context.text.titleSmall),
                      const SizedBox(height: 8),
                      RatingStars(value: j.rating!, size: 22),
                      if (j.review.isNotEmpty) ...[const SizedBox(height: 8), Text(j.review)],
                    ]),
                  ),
                ),
              ],
              if (assignedToMe && j.history.isNotEmpty) ...[
                const SectionHeader('Activity', padding: EdgeInsets.fromLTRB(4, 22, 0, 12)),
                Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 2), child: Timeline(entries: jobTimeline(context, j)))),
              ],
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: (canQuote || (assignedToMe && j.status == 'in_progress'))
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  if (canQuote && requestedMe) ...[
                    Expanded(child: OutlinedButton(onPressed: _busy ? null : _decline, child: const Text('Decline'))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: canQuote
                        ? FilledButton.icon(
                            onPressed: _busy ? null : _quote,
                            icon: const Icon(Icons.request_quote_rounded),
                            label: const Text('Send a quote'))
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: p.success),
                            onPressed: _busy ? null : _complete,
                            icon: const Icon(Icons.task_alt_rounded),
                            label: const Text('Mark as completed'),
                          ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _QuoteSheet extends StatefulWidget {
  final Job job;
  const _QuoteSheet({required this.job});

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  late final _amount = TextEditingController(text: widget.job.budget > 0 ? widget.job.budget.toStringAsFixed(0) : '');
  final _message = TextEditingController();
  int _eta = 1;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter your price');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiClient.post('/api/jobs/${widget.job.id}/bids', {'amount': amt, 'etaDays': _eta, 'message': _message.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send a quote', style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(widget.job.budget > 0 ? 'Client\'s budget: ${Fmt.money(widget.job.budget)}' : 'The client is open to quotes.',
              style: TextStyle(color: context.palette.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(labelText: 'Your price', prefixText: '${Fmt.currency} '),
          ),
          const SizedBox(height: 14),
          Text('When can you do it?', style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in const [0, 1, 2, 3, 5, 7])
              ChoiceChip(
                  label: Text(d == 0 ? 'Today' : (d == 1 ? 'Tomorrow' : 'In $d days')),
                  selected: _eta == d,
                  onSelected: (_) => setState(() => _eta = d)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Message to the client — what\'s included, materials, warranty…'),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: context.palette.danger, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Send quote'),
          ),
        ],
      ),
    );
  }
}
