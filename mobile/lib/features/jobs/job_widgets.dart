import 'package:flutter/material.dart';

import '../../kit.dart';

/// A job in a list. [viewer] tunes what is shown: clients see progress and
/// quotes on their own jobs; technicians see the budget and their own quote.
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final bool forTechnician;
  const JobCard(this.job, {super.key, this.onTap, this.forTechnician = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = serviceCategory(job.category);
    final me = Session.instance.user?.id ?? '';
    final myBid = forTechnician ? job.bidBy(me) : null;
    final status = jobStatus(job.status, stage: job.stage, directRequest: job.isDirectRequest, declined: job.requestDeclined);
    final urgent = job.urgency == 'high' || job.urgency == 'emergency';

    return Panel(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(cat.icon, color: cat.color, size: 44),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(job.title, style: context.text.titleSmall!.copyWith(fontSize: 15.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              Gap.h4,
              Text(
                [
                  cat.label,
                  if (job.distanceKm != null) '${distance(job.distanceKm!)} away' else if (job.area.isNotEmpty) job.area else if (job.city.isNotEmpty) job.city,
                  timeAgo(job.createdAt),
                ].join('  ·  '),
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Gap.w12,
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(job.price > 0 ? money(job.price) : 'Open', style: context.text.titleMedium),
            Text(job.agreedPrice != null ? 'agreed' : (job.price > 0 ? 'budget' : 'budget'), style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
          ]),
        ]),
        Gap.h12,
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (forTechnician && job.pending)
            myBid != null
                ? Pill('You quoted ${money(myBid.amount)}', tone: Tone.success, icon: AppIcons.check)
                : (job.isDirectRequest ? const Pill('Requested you', tone: Tone.brand, icon: AppIcons.bolt) : Pill.status(('Open for quotes', Tone.info)))
          else
            Pill.status(status),
          if (urgent && !job.completed && !job.cancelled) Pill(urgencyLabel(job.urgency), tone: urgencyTone(job.urgency), icon: AppIcons.fire),
          if (job.pending) Pill(job.bidCount == 0 ? 'No quotes yet' : plural(job.bidCount, 'quote')),
          if (job.inProgress && job.payment.held) const Pill('In escrow', tone: Tone.info, icon: AppIcons.lock),
          if (job.completed && job.rating != null) Pill('${job.rating}.0', icon: AppIcons.starFill, tone: Tone.warning),
        ]),
        if (job.inProgress) ...[
          Gap.h12,
          StageTrack(job.stageIndex, compact: true),
        ],
        if (!forTechnician && job.technician != null && job.technician!.name.isNotEmpty) ...[
          Gap.h12,
          Row(children: [
            Avatar(name: job.technician!.name, image: job.technician!.avatar, size: 22),
            Gap.w8,
            Expanded(child: Text(job.technician!.name, style: context.text.bodySmall!.copyWith(color: c.body, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
        if (forTechnician && job.client.name.isNotEmpty && !job.pending) ...[
          Gap.h12,
          Row(children: [
            Avatar(name: job.client.name, image: job.client.avatar, size: 22),
            Gap.w8,
            Expanded(child: Text(job.client.name, style: context.text.bodySmall!.copyWith(color: c.body, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }
}

/// The four stages of a hired job: Hired → On the way → Working → Finished.
/// [compact] draws four progress segments; the full version adds icons and
/// labels.
class StageTrack extends StatelessWidget {
  final int current; // index into jobStages
  final bool compact;
  final bool completed; // the client confirmed
  const StageTrack(this.current, {super.key, this.compact = false, this.completed = false});

  static const _icons = [AppIcons.handshake, AppIcons.route, AppIcons.wrench, AppIcons.check];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = completed ? jobStages.length : current;
    if (compact) {
      return Semantics(
        label: 'Progress: ${stageLabels[jobStages[current]]}',
        child: Row(children: [
          for (var i = 0; i < jobStages.length; i++) ...[
            if (i > 0) Gap.w4,
            Expanded(
              child: Container(height: 5, decoration: BoxDecoration(color: i <= done ? c.brand : c.sunken, borderRadius: BorderRadius.circular(3))),
            ),
          ],
        ]),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < jobStages.length; i++)
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= done ? c.brand : c.line))),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: i < done || (i == done && completed) ? c.brand : (i == done ? c.brandSoft : c.sunken),
                  shape: BoxShape.circle,
                  border: i == done && !completed ? Border.all(color: c.brand, width: 2) : null,
                ),
                child: Icon(i < done ? AppIcons.check : _icons[i], size: 17, color: i < done ? c.onBrand : (i == done ? c.brandDeep : c.muted)),
              ),
              Expanded(child: Container(height: 3, color: i == jobStages.length - 1 ? Colors.transparent : (i < done ? c.brand : c.line))),
            ]),
            Gap.h8,
            Text(
              stageLabels[jobStages[i]]!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall!.copyWith(fontSize: 11.5, fontWeight: i == done ? FontWeight.w800 : FontWeight.w600, color: i <= done ? c.ink : c.muted),
            ),
          ]),
        ),
    ]);
  }
}

/// "Typical price" hint from the pricing service.
class EstimateBox extends StatelessWidget {
  final Estimate estimate;
  final String? lead;
  const EstimateBox(this.estimate, {super.key, this.lead});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!estimate.exists) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
      child: Row(children: [
        const IconTile(AppIcons.tag, tone: Tone.brand, size: 40),
        Gap.w12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(lead ?? 'Typical price for ${serviceCategory(estimate.category).label.toLowerCase()}', style: context.text.bodySmall!.copyWith(color: c.body)),
            Gap.h2,
            Text('${money(estimate.low)} – ${money(estimate.high)}', style: context.text.titleLarge),
            Gap.h2,
            Text(
              estimate.fromHistory ? 'Based on ${plural(estimate.samples, 'recent job')} on SureFix' : 'Guide range — quotes depend on the work',
              style: context.text.bodySmall!.copyWith(fontSize: 11.5),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// An AI-ranked technician: the match score, why they fit, and — on ranked
/// quotes — their price. [actions] go at the bottom.
class MatchCard extends StatelessWidget {
  final TechMatch match;
  final int? rank;
  final List<Widget> actions;
  final VoidCallback? onTap;
  const MatchCard(this.match, {super.key, this.rank, this.actions = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = match.technician;
    final best = rank == 1;
    final quote = match.bidId.isNotEmpty;
    return Panel(
      onTap: onTap,
      border: best ? c.brand : null,
      borderWidth: best ? 1.6 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (best) ...[const Pill('Best match', solid: true, icon: AppIcons.sparkleFill), Gap.h12],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: t.name, image: t.avatar, size: 48, online: t.online),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(t.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (t.verified) ...[Gap.w4, const VerifiedTick()],
              ]),
              if (t.headline.isNotEmpty) Text(t.headline, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Gap.h6,
              Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Rating(t.rating, t.ratingCount),
                Meta(AppIcons.work, plural(t.jobsCompleted, 'job')),
                DistanceText(km: t.distanceKm, place: t.distanceKm != null ? t.area : t.place),
              ]),
            ]),
          ),
          Gap.w8,
          Column(mainAxisSize: MainAxisSize.min, children: [
            MatchRing(match.matchPercent),
            Gap.h4,
            Text('match', style: context.text.bodySmall!.copyWith(fontSize: 11)),
          ]),
        ]),
        if (quote) ...[
          Gap.h12,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(money(match.amount), style: context.text.titleLarge),
                Gap.w8,
                Expanded(child: Text(etaLabel(match.etaDays), style: context.text.bodySmall!.copyWith(color: c.body))),
                if (match.bidStatus == 'accepted') const Pill('Hired', tone: Tone.success, icon: AppIcons.check),
                if (match.bidStatus == 'rejected') const Pill('Not chosen'),
              ]),
              if (match.message.isNotEmpty) ...[Gap.h6, Text('"${match.message}"', style: context.text.bodyMedium!.copyWith(fontSize: 13.5))],
            ]),
          ),
        ],
        if (match.reasons.isNotEmpty || match.notes.isNotEmpty) ...[
          Gap.h12,
          for (final r in match.reasons.take(4)) _Reason(r, good: true),
          for (final n in match.notes.take(2)) _Reason(n, good: false),
        ],
        if (actions.isNotEmpty) ...[
          Gap.h12,
          Row(children: [
            for (var i = 0; i < actions.length; i++) ...[if (i > 0) Gap.w8, Expanded(child: actions[i])],
          ]),
        ],
      ]),
    );
  }
}

class _Reason extends StatelessWidget {
  final String text;
  final bool good;
  const _Reason(this.text, {required this.good});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(good ? AppIcons.success : AppIcons.info, size: 15, color: good ? c.success : c.muted),
        ),
        Gap.w8,
        Expanded(child: Text(text, style: context.text.bodyMedium!.copyWith(fontSize: 13.5, color: good ? c.body : c.muted))),
      ]),
    );
  }
}

/// How a job is being paid, in words: escrow, cash, paid out, refunded.
class PaymentSummary extends StatelessWidget {
  final Job job;
  final bool forTechnician;
  const PaymentSummary(this.job, {super.key, this.forTechnician = false});

  @override
  Widget build(BuildContext context) {
    final p = job.payment;
    if (!p.exists) return const SizedBox.shrink();
    final status = paymentStatus(p.status);
    final explain = switch (p.status) {
      'held' => forTechnician
          ? 'The client has paid. ${money(p.net)} is released to your wallet when they confirm the job.'
          : 'Your payment is held safely by SureFix and only released when you confirm the job is done.',
      'released' => forTechnician ? '${money(p.net)} was added to your wallet.' : 'Payment was released to the technician.',
      'refunded' => forTechnician ? 'The payment went back to the client.' : '${money(p.amount)} was returned to your wallet.',
      'cash_due' => forTechnician ? 'The client pays you ${money(p.amount)} in cash when the work is done.' : 'Pay the technician ${money(p.amount)} in cash when the work is done.',
      'cash_paid' => 'Paid in cash, directly between you.',
      _ => '',
    };
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconTile(p.isWallet ? AppIcons.shield : AppIcons.cash, tone: status.$2 == Tone.neutral ? Tone.neutral : status.$2, size: 40),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.isWallet ? 'SureFix Wallet' : 'Cash', style: context.text.titleSmall),
              Text(status.$1, style: context.text.bodySmall),
            ]),
          ),
          Text(money(p.amount), style: context.text.titleLarge),
        ]),
        if (explain.isNotEmpty) ...[Gap.h12, Text(explain, style: context.text.bodyMedium!.copyWith(fontSize: 13.5))],
        if (forTechnician && p.isWallet && p.fee > 0) ...[
          Gap.h8,
          const Divider(),
          Gap.h4,
          KV('Job price', money(p.amount)),
          KV('SureFix fee', '− ${money(p.fee)}'),
          KV('You receive', money(p.net), strong: true),
        ],
      ]),
    );
  }
}
