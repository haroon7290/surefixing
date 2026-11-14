import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../account/report_sheet.dart';
import '../shell/shell.dart';
import '../wallet/wallet_screen.dart';
import 'job_detail_parts.dart';
import 'job_widgets.dart';

class _Data {
  final Job job;
  final List<TechMatch> ranked;
  final Estimate estimate;
  const _Data(this.job, this.ranked, this.estimate);
}

/// One job, for whoever is looking at it: the client who posted it, a
/// technician deciding whether to quote, the hired technician, or an admin.
class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _view = GlobalKey<AsyncViewState<_Data>>();
  bool _busy = false;

  String get _path => '/api/jobs/${widget.jobId}';
  User get _me => Session.instance.user!;

  Future<_Data> _load() async {
    final job = Job.fromJson(await Api.map(_path));
    var ranked = <TechMatch>[];
    var estimate = const Estimate();
    final mine = job.client.id == _me.id || _me.isAdmin;
    if (mine && job.bids.isNotEmpty) {
      try {
        ranked = (await Api.list('$_path/ranked-bids')).map(TechMatch.fromJson).toList();
      } catch (_) {
        // Fall back to the plain list of quotes below.
      }
    }
    if (job.pending && _me.isTechnician) {
      try {
        estimate = Estimate.fromJson(await Api.map('/api/ai/estimate', query: {'category': job.category, 'urgency': job.urgency}));
      } catch (_) {}
    }
    return _Data(job, ranked, estimate);
  }

  /// Runs an action, then refreshes. Returns true when it worked.
  Future<bool> _act(Future<dynamic> Function() call, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await call();
      if (done != null) toastOk(done);
      await _view.currentState?.reload();
      Session.instance.refresh();
      return true;
    } on ApiError catch (e) {
      if (e.insufficientFunds) {
        toast(e.message, kind: ToastKind.error, actionLabel: 'Add funds', onAction: () => openSection(navigatorKey.currentContext!, 'wallet'));
      } else {
        toastError(e);
      }
      return false;
    } catch (e) {
      toastError(e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------- client actions

  Future<void> _hire(Job job, String bidId, String name, double amount) async {
    final method = await choosePayment(
      context,
      title: 'Hire $name',
      amount: amount,
      confirmLabel: 'Hire',
      walletNote: 'The price is held in escrow now and released to $name only when you confirm the job is done. Cancel before work starts and it all comes back.',
      cashNote: 'You pay $name ${money(amount)} in person when the work is done. Cash payments are not protected by escrow.',
    );
    if (method == null) return;
    await _act(() => Api.post('$_path/accept/$bidId', {'paymentMethod': method}), done: '$name is hired');
  }

  Future<void> _confirm(Job job) async {
    final wallet = job.payment.held;
    final ok = await confirm(
      context,
      title: 'Confirm the job is done?',
      message: wallet
          ? '${money(job.payment.amount)} will be released from escrow to ${job.technician?.name ?? 'the technician'}. This cannot be undone.'
          : 'Confirm once you have paid ${job.technician?.name ?? 'the technician'} ${money(job.price)} in cash.',
      confirmLabel: wallet ? 'Release payment' : 'Confirm',
      icon: AppIcons.shield,
    );
    if (ok) await _act(() => Api.post('$_path/complete'), done: 'Job completed. Thanks for using SureFix!');
  }

  Future<void> _cancel(Job job) async {
    final reason = await promptText(
      context,
      title: 'Cancel this job?',
      message: job.payment.held ? '${money(job.payment.amount)} will be returned to your wallet.' : 'Technicians who quoted will be told the job is off.',
      label: 'Reason',
      hint: 'e.g. Fixed it myself',
      confirmLabel: 'Cancel job',
      danger: true,
    );
    if (reason != null) await _act(() => Api.post('$_path/cancel', {'reason': reason}), done: 'Job cancelled');
  }

  Future<void> _rate(Job job) async {
    final res = await showRateSheet(context, name: job.technician?.firstName ?? 'your technician');
    if (res != null) await _act(() => Api.post('$_path/rate', res), done: 'Thanks for your review');
  }

  // --------------------------------------------------- technician actions

  Future<void> _finish() async {
    final report = await showDoneSheet(context);
    if (report == null) return;
    await _act(() => Api.upload('$_path/done', fields: {'note': report.note}, files: {'images': report.photos}), done: 'Marked as finished — the client was asked to confirm');
  }

  Future<void> _withdrawFromJob() async {
    final reason = await promptText(
      context,
      title: 'Withdraw from this job?',
      message: 'The client is refunded and the job reopens for other technicians. Only do this if you really cannot do the work.',
      label: 'Reason',
      hint: 'e.g. Emergency came up',
      confirmLabel: 'Withdraw',
      danger: true,
      mandatory: true,
    );
    if (reason == null || _busy) return;
    setState(() => _busy = true);
    try {
      await Api.post('$_path/withdraw', {'reason': reason});
      toast('You withdrew from the job');
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final reason = await promptText(context, title: 'Decline this request?', label: 'Reason', hint: 'e.g. Fully booked this week', confirmLabel: 'Decline', danger: true);
    if (reason == null) return;
    if (await _act(() => Api.post('$_path/decline', {'reason': reason})) && mounted) {
      toast('Request declined');
      Navigator.of(context).maybePop();
    }
  }

  // --------------------------------------------------------- admin actions

  Future<void> _resolve(String action) async {
    final refund = action == 'refund';
    final note = await promptText(
      context,
      title: refund ? 'Refund the client?' : 'Release to the technician?',
      message: refund ? 'The job is cancelled and any escrow goes back to the client.' : 'The job is completed and any escrow is paid to the technician.',
      label: 'Note for both sides',
      confirmLabel: refund ? 'Refund client' : 'Release payment',
      danger: refund,
    );
    if (note != null) await _act(() => Api.post('/api/admin/jobs/${widget.jobId}/resolve', {'action': action, 'note': note}), done: 'Dispute resolved');
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) => AsyncView<_Data>(
        key: _view,
        load: _load,
        events: Live.jobs,
        loading: const AppPage(title: 'Job', body: SkeletonList()),
        builder: (context, d) => _body(context, d),
      );

  Widget _body(BuildContext context, _Data d) {
    final c = context.colors;
    final job = d.job;
    final me = _me;
    final isClient = job.client.id == me.id;
    final isAssigned = job.technician?.id == me.id;
    final isTech = me.isTechnician;
    final myBid = isTech ? job.bidBy(me.id) : null;
    final cat = serviceCategory(job.category);
    final status = jobStatus(job.status, stage: job.stage, directRequest: job.isDirectRequest, declined: job.requestDeclined);
    final other = isClient ? job.technician : job.client;
    final showOther = other != null && other.name.isNotEmpty && (isClient ? job.technician != null : true);

    final header = Panel(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(cat.icon, color: cat.color, size: 50),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(job.title, style: context.text.headlineSmall),
              Gap.h6,
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill.status(status),
                Pill(cat.label),
                Pill(urgencyLabel(job.urgency), tone: urgencyTone(job.urgency)),
              ]),
            ]),
          ),
        ]),
        Gap.h16,
        Wrap(spacing: 16, runSpacing: 8, children: [
          if (job.place.isNotEmpty || job.location.isNotEmpty)
            Meta(AppIcons.pin, job.location.isNotEmpty && (isClient || isAssigned || me.isAdmin) ? [job.location, job.place].where((e) => e.isNotEmpty).join(', ') : job.place),
          if (job.distanceKm != null && !isClient) Meta(AppIcons.route, '${distance(job.distanceKm!)} from you', color: job.distanceKm! <= 5 ? context.colors.success : null),
          Meta(AppIcons.clock, 'Posted ${timeAgo(job.createdAt)}'),
          if (job.preferredDate != null) Meta(AppIcons.calendar, 'Preferred ${shortDate(job.preferredDate)}'),
          if (job.pending) Meta(AppIcons.tag, job.bidCount == 0 ? 'No quotes yet' : plural(job.bidCount, 'quote')),
        ]),
        Gap.h16,
        const Divider(),
        Gap.h12,
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(job.agreedPrice != null ? 'Agreed price' : 'Client budget', style: context.text.bodySmall),
              Text(job.price > 0 ? money(job.price) : 'Open to offers', style: context.text.headlineMedium),
            ]),
          ),
          if (job.pending && job.lowestBid != null && isClient)
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text('Lowest quote', style: context.text.bodySmall),
              Text(money(job.lowestBid), style: context.text.titleLarge),
            ]),
        ]),
      ]),
    );

    final next = _nextStep(context, d, isClient: isClient, isAssigned: isAssigned, myBid: myBid);

    final about = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('The problem', style: context.text.titleMedium),
        Gap.h8,
        Text(job.description, style: context.text.bodyLarge!.copyWith(fontSize: 15)),
        if (job.images.isNotEmpty) ...[Gap.h12, PhotoStrip(job.images)],
      ]),
    );

    final proof = job.doneAt == null || (job.completionNote.isEmpty && job.completionImages.isEmpty)
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const IconTile(AppIcons.check, tone: Tone.success, size: 34, round: true),
                Gap.w12,
                Expanded(child: Text('Work report', style: context.text.titleMedium)),
                Text(timeAgo(job.doneAt), style: context.text.bodySmall),
              ]),
              if (job.completionNote.isNotEmpty) ...[Gap.h12, Text(job.completionNote, style: context.text.bodyLarge!.copyWith(fontSize: 15))],
              if (job.completionImages.isNotEmpty) ...[Gap.h12, PhotoStrip(job.completionImages)],
            ]),
          );

    final review = job.rating == null
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(isClient ? 'Your review' : 'Client review', style: context.text.titleMedium)),
                Stars(job.rating!.toDouble(), size: 18),
              ]),
              if (job.review.isNotEmpty) ...[Gap.h8, Text('"${job.review}"', style: context.text.bodyLarge!.copyWith(fontSize: 15))],
            ]),
          );

    final person = !showOther
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(isClient ? 'Your technician' : 'Client', style: context.text.bodySmall),
              Gap.h8,
              PersonRow(
                name: other.name,
                image: other.avatar,
                verified: other.verified,
                below: isClient ? Rating(other.rating, other.ratingCount) : (other.city.isEmpty ? null : Meta(AppIcons.pin, other.city)),
                size: 48,
                onTap: isClient ? () => openTechnician(context, other.id) : null,
              ),
              if (other.phone.isNotEmpty) ...[
                Gap.h12,
                Semantics(
                  button: true,
                  label: 'Copy phone number ${other.phone}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(R.sm),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: other.phone));
                      toast('Phone number copied');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.sm)),
                      child: Row(children: [
                        Icon(AppIcons.phone, size: 16, color: c.body),
                        Gap.w8,
                        Expanded(child: Text(other.phone, style: context.text.titleSmall)),
                        Icon(AppIcons.copy, size: 15, color: c.muted),
                      ]),
                    ),
                  ),
                ),
              ],
              if (!me.isAdmin && !job.cancelled && (isClient || isAssigned || myBid != null || job.requestedTechnician?.id == me.id)) ...[
                Gap.h12,
                Btn('Message ${other.firstName}',
                    icon: AppIcons.chat,
                    kind: BtnKind.dark,
                    expand: true,
                    onPressed: () => openChat(context, ChatTarget(jobId: job.id, otherId: other.id, otherName: other.name, otherAvatar: other.avatar, subject: job.title))),
              ],
            ]),
          );

    final quotes = isClient || me.isAdmin ? _quotes(context, d, canHire: isClient) : null;

    final quoting = !isTech || !job.pending
        ? null
        : (myBid != null
            ? Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('Your quote', style: context.text.titleMedium)),
                    Pill(myBid.status == 'withdrawn' ? 'Withdrawn' : 'Sent', tone: myBid.status == 'withdrawn' ? Tone.neutral : Tone.success, icon: AppIcons.check),
                  ]),
                  Gap.h8,
                  Text(money(myBid.amount), style: context.text.headlineMedium),
                  Text(etaLabel(myBid.etaDays), style: context.text.bodySmall),
                  if (myBid.message.isNotEmpty) ...[Gap.h8, Text('"${myBid.message}"', style: context.text.bodyMedium)],
                  if (myBid.pending) ...[
                    Gap.h12,
                    Btn('Withdraw quote',
                        kind: BtnKind.outline,
                        size: BtnSize.sm,
                        onPressed: _busy
                            ? null
                            : () async {
                                if (await confirm(context,
                                    title: 'Withdraw your quote?', message: 'The client will no longer be able to hire you for this job.', confirmLabel: 'Withdraw', danger: true)) {
                                  _act(() => Api.delete('$_path/bids/me'), done: 'Quote withdrawn');
                                }
                              }),
                  ],
                ]),
              )
            : QuoteForm(job: job, estimate: d.estimate, onSubmit: (body) => _act(() => Api.post('$_path/bids', body), done: 'Quote sent')));

    final timeline = (isClient || isAssigned || me.isAdmin) && job.history.isNotEmpty
        ? Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Activity', style: context.text.titleMedium),
              Gap.h16,
              JobTimeline(job.history),
            ]),
          )
        : null;

    final secondary = <Widget>[
      if (isClient && (job.pending || job.beforeWork)) Btn('Cancel job', kind: BtnKind.danger, expand: true, onPressed: _busy ? null : () => _cancel(job)),
      if (isAssigned && job.beforeWork) Btn('Withdraw from job', kind: BtnKind.danger, expand: true, onPressed: _busy ? null : _withdrawFromJob),
      if (!me.isAdmin && (isClient || isAssigned))
        Btn('Report a problem',
            icon: AppIcons.reports,
            kind: BtnKind.ghost,
            expand: true,
            onPressed: () => showReportSheet(context, targetType: 'job', targetId: job.id, label: job.title, suggested: job.inProgress ? 'payment' : null)),
    ];

    Widget gap(Widget? w) => w == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: w);

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      gap(header),
      gap(next),
      if (job.inProgress || job.completed) gap(Panel(padding: const EdgeInsets.fromLTRB(8, 18, 8, 16), child: StageTrack(job.stageIndex, completed: job.completed))),
      if (!context.isWide) ...[gap(person), gap(quoting)],
      gap(proof),
      gap(review),
      gap(about),
      gap(quotes),
      gap(timeline),
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (context.isWide) ...[gap(person), gap(quoting)],
      if (job.payment.exists && (isClient || isAssigned || me.isAdmin)) gap(PaymentSummary(job, forTechnician: isAssigned)),
      for (final b in secondary) Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
    ]);

    return AppPage(
      title: context.isWide ? 'Job details' : 'Job',
      body: PageList(onRefresh: () => _view.currentState!.reload(), children: [TwoCol(main: main, side: side)]),
    );
  }

  /// The card that says what is happening and what to do about it.
  Widget? _nextStep(BuildContext context, _Data d, {required bool isClient, required bool isAssigned, required Bid? myBid}) {
    final job = d.job;
    final me = _me;
    final tech = job.technician?.firstName ?? 'The technician';

    Widget card(Tone tone, IconData icon, String title, String body, [List<Widget> actions = const []]) => Notice(
          body,
          title: title,
          tone: tone,
          icon: icon,
          action: actions.isEmpty ? null : Wrap(spacing: 8, runSpacing: 8, children: actions),
        );

    if (me.isAdmin) {
      if (!job.inProgress) return null;
      return card(Tone.neutral, AppIcons.scales, 'Dispute tools', 'Settle this job if the two sides cannot agree. Both are notified.', [
        Btn('Refund client', kind: BtnKind.danger, size: BtnSize.sm, onPressed: _busy ? null : () => _resolve('refund')),
        Btn('Release to technician', kind: BtnKind.dark, size: BtnSize.sm, onPressed: _busy ? null : () => _resolve('release')),
      ]);
    }

    if (job.cancelled) {
      return card(Tone.neutral, AppIcons.blocked, 'This job was cancelled', job.cancelReason.isEmpty ? 'No reason was given.' : 'Reason: ${job.cancelReason}');
    }

    if (isClient) {
      if (job.pending) {
        final requested = job.requestedTechnician;
        if (requested != null) {
          final open = Btn('Open to all technicians',
              kind: job.requestDeclined ? BtnKind.primary : BtnKind.dark,
              size: BtnSize.sm,
              onPressed: _busy ? null : () => _act(() => Api.post('$_path/open'), done: 'Your job is now open for quotes'));
          return job.requestDeclined
              ? card(Tone.danger, AppIcons.blocked, '${requested.firstName} cannot take this job', 'Open it to every technician to get quotes from others.', [open])
              : (job.bids.isEmpty
                  ? card(Tone.info, AppIcons.hourglass, 'Waiting for ${requested.firstName} to reply', 'You sent this request only to them. Not hearing back? Open it to everyone.', [open])
                  : card(Tone.brand, AppIcons.tag, '${requested.firstName} sent a quote', 'Review it below and hire when you are ready.'));
        }
        return job.bids.isEmpty
            ? card(Tone.info, AppIcons.hourglass, 'Waiting for quotes', 'Technicians who do this kind of work have been notified. Quotes usually arrive within the hour.')
            : card(Tone.brand, AppIcons.sparkleFill, 'You have ${plural(job.openBids.length, 'quote')}', 'They are ranked by how well each technician fits this job. Hire the one you like.');
      }
      if (job.inProgress) {
        return switch (job.stage) {
          'done' => card(
              Tone.warning,
              AppIcons.warningFill,
              '$tech says the work is finished',
              job.payment.held
                  ? 'Check the work, then confirm to release ${money(job.payment.amount)} from escrow. Not right? Report a problem instead.${job.autoCompleteAt == null ? '' : ' If you do nothing, $tech can close the job in ${timeLeft(job.autoCompleteAt)}.'}'
                  : 'Check the work and pay $tech in cash, then confirm to close the job.',
              [Btn(job.payment.held ? 'Confirm & release payment' : 'Confirm job is done', icon: AppIcons.check, loading: _busy, onPressed: () => _confirm(job))],
            ),
          'working' => card(Tone.brand, AppIcons.wrench, '$tech is working on it', 'You will be asked to confirm when the work is finished.'),
          'on_the_way' => card(Tone.brand, AppIcons.route, '$tech is on the way', 'Keep your phone nearby in case they need directions.'),
          _ => card(Tone.brand, AppIcons.handshake, 'You hired $tech', 'They will update you when they set off. You can message or call them any time.'),
        };
      }
      if (job.completed && job.rating == null) {
        return card(Tone.success, AppIcons.success, 'Job completed', 'How did $tech do? Your review helps other customers.',
            [Btn('Rate $tech', icon: AppIcons.star, onPressed: _busy ? null : () => _rate(job))]);
      }
      return card(Tone.success, AppIcons.success, 'Job completed', 'Thanks for using SureFix.');
    }

    // Technician.
    if (job.pending) {
      if (myBid != null) return null; // their quote card says it all
      if (job.requestedTechnician?.id == me.id) {
        return card(Tone.brand, AppIcons.bolt, '${job.client.firstName} asked for you', 'This request was sent only to you. Send a quote, or decline so they can ask someone else.',
            [Btn('Decline request', kind: BtnKind.outline, size: BtnSize.sm, onPressed: _busy ? null : _decline)]);
      }
      return null;
    }
    if (!isAssigned) return card(Tone.neutral, AppIcons.info, 'This job is no longer open', 'The client hired another technician.');
    if (job.inProgress) {
      return switch (job.stage) {
        'hired' => card(Tone.brand, AppIcons.handshake, 'You got the job', 'Let ${job.client.firstName} know when you set off.', [
            Btn("I'm on my way", icon: AppIcons.route, loading: _busy, onPressed: () => _act(() => Api.patch('$_path/stage', {'stage': 'on_the_way'}), done: 'The client was told you are on the way')),
            Btn('Start work', kind: BtnKind.outline, onPressed: _busy ? null : () => _act(() => Api.patch('$_path/stage', {'stage': 'working'}), done: 'Work started')),
          ]),
        'on_the_way' => card(Tone.brand, AppIcons.route, 'On the way', 'Tap when you arrive and begin.', [
            Btn('Start work', icon: AppIcons.wrench, loading: _busy, onPressed: () => _act(() => Api.patch('$_path/stage', {'stage': 'working'}), done: 'Work started')),
          ]),
        'working' => card(Tone.brand, AppIcons.wrench, 'Work in progress', 'When you are finished, send the client a short report so they can confirm and pay.', [
            Btn('Mark as finished', icon: AppIcons.check, loading: _busy, onPressed: _finish),
          ]),
        _ => () {
            final at = job.autoCompleteAt;
            final canClose = at != null && !at.isAfter(DateTime.now());
            return card(
              Tone.warning,
              AppIcons.hourglass,
              'Waiting for the client to confirm',
              canClose
                  ? 'The client has not responded in time. You can close the job and receive your payment.'
                  : 'You are paid as soon as they confirm.${at == null ? '' : ' If they do not respond you can close the job yourself in ${timeLeft(at)}.'}',
              [if (canClose) Btn('Close job & get paid', icon: AppIcons.check, loading: _busy, onPressed: () => _act(() => Api.post('$_path/complete'), done: 'Job closed'))],
            );
          }(),
      };
    }
    return card(
      Tone.success,
      AppIcons.success,
      'Job completed',
      job.payment.released ? '${money(job.payment.net)} was added to your wallet.' : 'Nice work. The client paid in cash.',
    );
  }

  /// The client's list of quotes: AI-ranked when available.
  Widget? _quotes(BuildContext context, _Data d, {required bool canHire}) {
    final job = d.job;
    if (job.bids.isEmpty) return null;
    final hiring = canHire && job.pending;

    List<Widget> actionsFor(String bidId, User tech, double amount, String status) => !hiring || status != 'pending'
        ? const []
        : [
            Btn('Message',
                icon: AppIcons.chat,
                kind: BtnKind.outline,
                expand: true,
                onPressed: () => openChat(context, ChatTarget(jobId: job.id, otherId: tech.id, otherName: tech.name, otherAvatar: tech.avatar, subject: job.title))),
            Btn('Hire · ${money(amount)}', expand: true, onPressed: _busy ? null : () => _hire(job, bidId, tech.firstName, amount)),
          ];

    final cards = d.ranked.isNotEmpty
        ? [
            for (final (i, m) in d.ranked.indexed)
              MatchCard(m, rank: job.pending ? i + 1 : null, onTap: () => openTechnician(context, m.technician.id), actions: actionsFor(m.bidId, m.technician, m.amount, m.bidStatus)),
          ]
        : [
            for (final b in job.openBids)
              MatchCard(
                TechMatch(technician: b.technician, bidId: b.id, amount: b.amount, etaDays: b.etaDays, message: b.message, bidStatus: b.status, matchPercent: 0),
                onTap: () => openTechnician(context, b.technician.id),
                actions: actionsFor(b.id, b.technician, b.amount, b.status),
              ),
          ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(job.pending ? 'Quotes' : 'Quotes received', style: context.text.titleLarge)),
          if (d.ranked.isNotEmpty) const Pill('Ranked by AI', icon: AppIcons.sparkleFill, tone: Tone.brand),
        ]),
      ),
      for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
    ]);
  }
}
