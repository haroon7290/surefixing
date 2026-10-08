import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/recommendation.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/match_card.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shared/chat_screen.dart';
import '../shared/report_sheet.dart';
import '../shared/technician_profile_screen.dart';

/// Job detail for its client (and read-only for admins): status, quotes
/// ranked by the AI, hiring, completion, review and the activity timeline.
class JobDetailClient extends StatefulWidget {
  final String jobId;
  const JobDetailClient({super.key, required this.jobId});

  @override
  State<JobDetailClient> createState() => _JobDetailClientState();
}

class _JobDetailClientState extends State<JobDetailClient> {
  Job? _job;
  List<TechMatch> _ranked = [];
  Object? _error;
  bool _busy = false;
  StreamSubscription? _sub;

  bool get _isOwner => _job != null && _job!.clientId == AuthService.instance.user?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'job:bid', 'job:status', 'job:rated'}).where((e) => e.jobId == widget.jobId).listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final job = Job.fromJson(await ApiClient.getMap('/api/jobs/${widget.jobId}'));
      List<TechMatch> ranked = [];
      final me = AuthService.instance.user!;
      if (job.bids.isNotEmpty && (job.clientId == me.id || me.isAdmin)) {
        final res = await ApiClient.getList('/api/jobs/${widget.jobId}/ranked-bids');
        ranked = res.map(TechMatch.fromJson).toList();
      }
      if (!mounted) return;
      setState(() {
        _job = job;
        _ranked = ranked;
        _error = null;
      });
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

  Future<void> _accept(TechMatch m) async {
    final ok = await confirmDialog(
      context,
      title: 'Hire ${m.name}?',
      message:
          'You\'re accepting a quote of ${Fmt.money(m.amount)}. Other quotes will be declined and ${m.name.split(' ').first} will be notified.',
      confirm: 'Hire',
    );
    if (!ok) return;
    await _run(() => ApiClient.post('/api/jobs/${widget.jobId}/accept/${m.bidId}'), '${m.name} hired! You can now chat and share details.');
  }

  Future<void> _complete() async {
    final ok = await confirmDialog(context,
        title: 'Mark job as completed?', message: 'Confirm the work is done to your satisfaction.', confirm: 'Mark completed');
    if (!ok) return;
    await _run(() => ApiClient.patch('/api/jobs/${widget.jobId}/status', {'status': 'completed'}), 'Job completed 🎉');
    if (mounted && _job?.status == 'completed' && _job?.rating == null) _rate();
  }

  Future<void> _cancel() async {
    final reason = await promptDialog(
      context,
      title: 'Cancel this job?',
      message: _job!.status == 'in_progress' ? 'The technician will be notified.' : 'Technicians will no longer be able to quote.',
      hint: 'Reason (optional)',
      confirm: 'Cancel job',
      destructive: true,
    );
    if (reason == null) return;
    await _run(() => ApiClient.patch('/api/jobs/${widget.jobId}/status', {'status': 'cancelled', if (reason.isNotEmpty) 'note': reason}),
        'Job cancelled');
  }

  Future<void> _openToAll() => _run(() => ApiClient.post('/api/jobs/${widget.jobId}/open'), 'Your job is now visible to all technicians');

  Future<void> _rate() async {
    final tech = _job!.technician;
    final r = await showRatingSheet(context, title: 'How did ${tech?.name.split(' ').first ?? 'it'} do?', subtitle: _job!.title);
    if (r == null) return;
    await _run(() => ApiClient.post('/api/jobs/${widget.jobId}/rate', {'rating': r.rating, 'review': r.review}), 'Thanks for your review!');
  }

  void _chat(String otherId, String otherName) {
    push(context, ChatScreen(jobId: widget.jobId, otherId: otherId, otherName: otherName, jobTitle: _job!.title));
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList(count: 4),
      );
    }
    final j = _job!;
    final cat = Catalog.service(j.category);
    final canCancel = _isOwner && j.isActive;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: j.images.isNotEmpty ? 240 : 0,
              title: Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              flexibleSpace: j.images.isEmpty
                  ? null
                  : FlexibleSpaceBar(
                      background: GestureDetector(
                        onTap: () => PhotoViewer.open(context, j.images),
                        child: Stack(fit: StackFit.expand, children: [
                          NetImage(j.images.first, placeholder: cat),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [Colors.black45, Colors.transparent], begin: Alignment.topCenter, end: Alignment.center),
                            ),
                          ),
                          if (j.images.length > 1)
                            Positioned(
                                right: 12,
                                bottom: 12,
                                child: Pill('+${j.images.length - 1} photos',
                                    color: Colors.black54, solid: true, icon: Icons.photo_library_outlined)),
                        ]),
                      ),
                    ),
              actions: [
                if (canCancel || (j.technician != null && _isOwner))
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'cancel') _cancel();
                      if (v == 'report' && j.technician != null) {
                        showReportSheet(context, targetType: 'user', targetId: j.technician!.id, targetName: j.technician!.name);
                      }
                    },
                    itemBuilder: (_) => [
                      if (canCancel) const PopupMenuItem(value: 'cancel', child: Text('Cancel job')),
                      if (j.technician != null) const PopupMenuItem(value: 'report', child: Text('Report technician')),
                    ],
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList.list(
                children: [
                  _header(context, j, cat),
                  const SizedBox(height: 12),
                  ..._statusSection(context, j),
                  if (j.isOpen && !j.isDirectRequest) ..._quotes(context, j),
                  if (j.isOpen && j.isDirectRequest && _ranked.isNotEmpty) ..._quotes(context, j),
                  const SizedBox(height: 12),
                  _details(context, j),
                  if (j.history.isNotEmpty) ...[
                    const SectionHeader('Activity', padding: EdgeInsets.fromLTRB(4, 24, 0, 12)),
                    Card(
                        child: Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 2), child: Timeline(entries: _timeline(context, j)))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Job j, CategoryInfo cat) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CategoryIcon(cat, size: 40),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('${cat.label} · posted ${Fmt.ago(j.createdAt)}',
                        style: TextStyle(color: context.palette.muted, fontSize: 13))),
              ]),
              const SizedBox(height: 12),
              Text(j.title, style: context.text.titleLarge),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [StatusPill(j.status), UrgencyPill(j.urgency, hideNormal: false)]),
              if (AuthService.instance.user!.isAdmin) ...[
                const SizedBox(height: 12),
                Row(children: [
                  AppAvatar(name: j.client.name, url: j.client.avatar, size: 26),
                  const SizedBox(width: 8),
                  Text('Posted by ${j.client.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ],
            ],
          ),
        ),
      );

  List<Widget> _statusSection(BuildContext context, Job j) {
    final p = context.palette;
    final out = <Widget>[];
    if (j.isOpen && j.isDirectRequest) {
      final t = j.requestedTechnician!;
      out.add(_banner(
        context,
        color: j.requestDeclined ? p.danger : const Color(0xFF7A5AF8),
        icon: j.requestDeclined ? Icons.person_off_rounded : Icons.hourglass_top_rounded,
        title: j.requestDeclined ? '${t.name} can\'t take this job' : 'Waiting for ${t.name} to respond',
        body: j.requestDeclined
            ? 'Open it to all technicians to start receiving quotes.'
            : 'This is a private request. You\'ll be notified when they send a quote.',
        action: _isOwner
            ? (j.requestDeclined
                ? FilledButton(onPressed: _busy ? null : _openToAll, child: const Text('Open to all technicians'))
                : TextButton(onPressed: _busy ? null : _openToAll, child: const Text('Open to everyone instead')))
            : null,
      ));
    }
    if (j.technician != null && (j.status == 'in_progress' || j.status == 'completed')) {
      final t = j.technician!;
      out.add(_techCard(context, t, j));
    }
    if (j.status == 'in_progress' && _isOwner) {
      out.addAll([
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _busy ? null : _complete, icon: const Icon(Icons.task_alt_rounded), label: const Text('Mark as completed')),
      ]);
    }
    if (j.status == 'completed' && j.rating == null && _isOwner) {
      out.addAll([
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.accent),
          onPressed: _busy ? null : _rate,
          icon: const Icon(Icons.star_rounded),
          label: Text('Rate ${j.technician?.name.split(' ').first ?? 'the technician'}'),
        ),
      ]);
    }
    if (j.rating != null) {
      out.addAll([
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isOwner ? 'Your review' : 'Client review', style: context.text.titleSmall),
              const SizedBox(height: 8),
              RatingStars(value: j.rating!, size: 22),
              if (j.review.isNotEmpty) ...[const SizedBox(height: 8), Text(j.review)],
            ]),
          ),
        ),
      ]);
    }
    if (j.status == 'cancelled') {
      out.add(_banner(
        context,
        color: p.subtle,
        icon: Icons.cancel_outlined,
        title: 'This job was cancelled',
        body: j.cancelReason.isEmpty ? 'No reason given.' : j.cancelReason,
      ));
    }
    return out;
  }

  Widget _techCard(BuildContext context, UserLite t, Job j) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(children: [
                AppAvatar(name: t.name, url: t.avatar, size: 52, verified: t.isVerified),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(j.status == 'completed' ? 'Completed by' : 'Your technician',
                        style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
                    Text(t.name, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    RatingLabel(rating: t.rating, count: t.ratingCount, size: 12.5),
                  ]),
                ),
                if (j.agreedPrice != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Fmt.money(j.agreedPrice), style: context.text.titleMedium?.copyWith(color: context.colors.primary)),
                    Text('agreed', style: TextStyle(fontSize: 11.5, color: context.palette.subtle)),
                  ]),
              ]),
              if ((t.phone ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.phone_rounded, size: 18, color: context.palette.success),
                  const SizedBox(width: 8),
                  SelectableText(t.phone!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => push(context, TechnicianProfileScreen(technicianId: t.id)),
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('Profile'),
                  ),
                ),
                if (_isOwner) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _chat(t.id, t.name),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('Chat'),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      );

  List<Widget> _quotes(BuildContext context, Job j) {
    if (_ranked.isEmpty) {
      if (j.isDirectRequest) return [];
      return [
        const SizedBox(height: 4),
        Card(
          child: EmptyState(
            compact: true,
            icon: Icons.mark_email_unread_outlined,
            title: 'Waiting for quotes',
            message:
                'We\'ve notified ${Catalog.service(j.category).label.toLowerCase()} technicians. Quotes usually arrive within the hour.',
          ),
        ),
      ];
    }
    final engine = _ranked.first.engine;
    return [
      SectionHeader(
        'Quotes (${_ranked.length})',
        padding: const EdgeInsets.fromLTRB(4, 12, 0, 4),
        trailing: Pill(engine == 'ai-service' ? 'Ranked by SureFix AI' : 'Smart ranking',
            color: const Color(0xFF7A5AF8), icon: Icons.auto_awesome_rounded),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text('Ordered by fit: skills, reviews, reliability, response time, distance and price.',
            style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
      ),
      for (var i = 0; i < _ranked.length; i++) ...[
        MatchCard(
          match: _ranked[i],
          rank: i,
          showQuote: true,
          onTap: () => push(context, TechnicianProfileScreen(technicianId: _ranked[i].technicianId)),
          actions: _isOwner
              ? [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _chat(_ranked[i].technicianId, _ranked[i].name),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Ask'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: _busy ? null : () => _accept(_ranked[i]),
                    child: const Text('Hire'),
                  ),
                ]
              : const [],
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _details(BuildContext context, Job j) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: context.text.titleSmall),
              const SizedBox(height: 8),
              Text(j.description, style: context.text.bodyMedium),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 6),
              InfoRow(icon: Icons.payments_outlined, label: 'Budget', value: j.budget > 0 ? Fmt.money(j.budget) : 'Open to quotes'),
              if (j.preferredDate != null)
                InfoRow(icon: Icons.event_outlined, label: 'Preferred date', value: Fmt.weekday(j.preferredDate)),
              if (j.city.isNotEmpty) InfoRow(icon: Icons.location_city_outlined, label: 'City', value: j.city),
              if (j.location.isNotEmpty) InfoRow(icon: Icons.home_outlined, label: 'Address', value: j.location),
              if (j.images.length > 1) ...[
                const SizedBox(height: 10),
                PhotoStrip(images: j.images, size: 84),
              ],
            ],
          ),
        ),
      );

  Widget _banner(BuildContext context,
          {required Color color, required IconData icon, required String title, required String body, Widget? action}) =>
      Card(
        color: color.withValues(alpha: context.isDark ? 0.16 : 0.07),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.35))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body, style: TextStyle(color: context.palette.muted, fontSize: 13)),
                  ]),
                ),
              ]),
              if (action != null) ...[const SizedBox(height: 10), action],
            ],
          ),
        ),
      );
}

/// Maps the job's history events to timeline rows.
List<TimelineEntry> _timeline(BuildContext context, Job j) {
  final p = context.palette;
  return j.history.reversed.map((h) {
    final (String title, IconData icon, Color color) = switch (h.status) {
      'pending' => ('Job posted', Icons.campaign_rounded, p.info),
      'bid' => ('New quote', Icons.request_quote_rounded, context.colors.primary),
      'bid_withdrawn' => ('Quote withdrawn', Icons.undo_rounded, p.subtle),
      'request_declined' => ('Request declined', Icons.person_off_rounded, p.danger),
      'opened' => ('Opened to all technicians', Icons.public_rounded, p.info),
      'in_progress' => ('Technician hired', Icons.handshake_rounded, p.warning),
      'completed' => ('Job completed', Icons.task_alt_rounded, p.success),
      'cancelled' => ('Job cancelled', Icons.cancel_rounded, p.subtle),
      'rated' => ('Review left', Icons.star_rounded, p.star),
      _ => (Fmt.titleCase(h.status), Icons.circle, p.subtle),
    };
    // Notes like "Ahmad quoted 2800" end with a raw amount; show it as money.
    final note = h.note.replaceAllMapped(RegExp(r'(quoted|for) (\d+(?:\.\d+)?)$'), (m) => '${m[1]} ${Fmt.money(num.parse(m[2]!))}');
    return TimelineEntry(title: title, subtitle: note.toLowerCase() == title.toLowerCase() ? '' : note, at: h.at, icon: icon, color: color);
  }).toList();
}

/// Shared with the technician job screen.
List<TimelineEntry> jobTimeline(BuildContext context, Job j) => _timeline(context, j);
