import 'package:flutter/material.dart';

import '../../kit.dart';
import '../technicians/tech_widgets.dart';

/// A tool in the market: photo, name, rating and the daily rate.
class ToolCard extends StatelessWidget {
  final Tool tool;
  final VoidCallback? onTap;
  final bool showFavorite;
  const ToolCard(this.tool, {super.key, this.onTap, this.showFavorite = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = toolCategory(tool.category);
    return Panel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            CoverImage(tool.image, category: cat, label: tool.name),
            Positioned(
              left: 10,
              top: 10,
              child: !tool.rentable ? const Pill('Unavailable', tone: Tone.neutral) : (tool.hasInstallments ? const Pill('Buy monthly', solid: true) : const SizedBox.shrink()),
            ),
            if (showFavorite) Positioned(right: 8, top: 8, child: FavoriteButton(type: 'tool', id: tool.id, size: 34, onImage: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(tool.name, style: context.text.titleSmall!.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Gap.h4,
            Row(children: [
              Rating(tool.rating, tool.ratingCount, size: 12),
              if (tool.distanceKm != null || tool.city.isNotEmpty) ...[
                Gap.w8,
                Flexible(child: DistanceText(km: tool.distanceKm, place: tool.area.isNotEmpty ? tool.area : tool.city, compact: true)),
              ],
            ]),
            Gap.h8,
            Text.rich(
              TextSpan(children: [
                TextSpan(text: money(tool.rentPricePerDay), style: context.text.titleMedium),
                TextSpan(text: ' /day', style: context.text.bodySmall!.copyWith(color: c.muted)),
              ]),
              maxLines: 1,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A rental or installment plan in a list.
class RentalCard extends StatelessWidget {
  final Rental rental;
  final bool forSupplier;
  final VoidCallback? onTap;
  final List<Widget> actions;
  const RentalCard(this.rental, {super.key, this.forSupplier = false, this.onTap, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = rental;
    final cat = toolCategory(r.tool.category);
    final status = rentalStatus(r.status, installment: r.isInstallment, overdue: r.overdue);
    final other = forSupplier ? r.renter : r.supplier;
    final period = r.isInstallment ? '${r.monthsPaid} of ${r.monthsTotal} months paid' : '${shortDate(r.startDate)} → ${shortDate(r.endDate)}  ·  ${plural(r.days, 'day')}';

    return Panel(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(R.md),
            child: SizedBox.square(dimension: 60, child: CoverImage(r.tool.image, category: cat, iconSize: 26)),
          ),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(r.tool.name.isEmpty ? 'Tool' : r.tool.name, style: context.text.titleSmall!.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              Gap.h2,
              Text(period, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Gap.h6,
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill.status(status),
                Pill(r.isInstallment ? 'Installments' : (r.handover.delivery ? 'Delivery' : 'Pickup'),
                    icon: r.isInstallment ? AppIcons.calendar : (r.handover.delivery ? AppIcons.truck : AppIcons.store)),
                if (r.payment.held) const Pill('In escrow', tone: Tone.info, icon: AppIcons.lock),
              ]),
            ]),
          ),
          Gap.w8,
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(money(r.isInstallment ? r.monthlyAmount : r.totalCost), style: context.text.titleMedium),
            Text(r.isInstallment ? 'per month' : 'total', style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
          ]),
        ]),
        if (r.isInstallment && r.active) ...[Gap.h12, ProgressLine(r.monthsTotal == 0 ? 0 : r.monthsPaid / r.monthsTotal)],
        if (r.overdue) ...[
          Gap.h12,
          Notice(
            forSupplier
                ? '${plural(r.lateDays, 'day')} late. A late fee of ${money(r.lateFee)} comes out of the deposit on return.'
                : '${plural(r.lateDays, 'day')} overdue — return it soon. Late fee so far: ${money(r.lateFee)} from your deposit.',
            tone: Tone.danger,
          ),
        ] else if (r.active && !r.isInstallment && r.daysLeft != null) ...[
          Gap.h8,
          Meta(AppIcons.timer, r.daysLeft! <= 0 ? 'Due back today' : 'Due back in ${plural(r.daysLeft!, 'day')}', color: r.daysLeft! <= 1 ? c.warning : null),
        ],
        if (other.name.isNotEmpty) ...[
          Gap.h12,
          Row(children: [
            Avatar(name: other.name, image: other.avatar, size: 22),
            Gap.w8,
            Expanded(
              child: Text('${forSupplier ? 'Customer' : 'Supplier'}: ${other.name}',
                  style: context.text.bodySmall!.copyWith(color: c.body, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
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
