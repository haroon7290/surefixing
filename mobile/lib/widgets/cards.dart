import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/job.dart';
import '../models/rental.dart';
import '../models/tool.dart';
import '../models/user.dart';
import 'app_avatar.dart';
import 'media.dart';
import 'pills.dart';
import 'rating_stars.dart';

/// Job row used in every job list (client, technician, admin).
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final String? viewerId; // technician viewing: show "You quoted"
  final bool showClient;

  const JobCard({super.key, required this.job, this.onTap, this.viewerId, this.showClient = false});

  @override
  Widget build(BuildContext context) {
    final cat = Catalog.service(job.category);
    final myBid = viewerId == null ? null : job.bidBy(viewerId!);
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: job.images.isNotEmpty
                        ? NetImage(job.images.first, width: 54, height: 54, placeholder: cat)
                        : CategoryIcon(cat, size: 54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(
                          [cat.label, if (job.city.isNotEmpty) job.city, Fmt.ago(job.createdAt)].join(' · '),
                          style: TextStyle(color: p.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job.agreedPrice != null ? Fmt.money(job.agreedPrice) : (job.budget > 0 ? Fmt.money(job.budget) : 'Quote'),
                    style: context.text.titleSmall?.copyWith(color: context.colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusPill(job.status),
                  UrgencyPill(job.urgency),
                  if (job.isDirectRequest && job.isOpen)
                    Pill(job.requestDeclined ? 'Request declined' : 'Direct request',
                        color: job.requestDeclined ? p.danger : const Color(0xFF7A5AF8), icon: Icons.person_pin_rounded),
                  if (myBid != null)
                    Pill('You quoted ${Fmt.money(myBid.amount)}', color: context.colors.primary, icon: Icons.gavel_rounded),
                  if (job.isOpen && job.bids.isNotEmpty && myBid == null)
                    Pill(Fmt.plural(job.bids.length, 'quote'), color: p.muted, icon: Icons.request_quote_outlined),
                ],
              ),
              if (job.technician != null || showClient) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (job.technician != null) ...[
                      AppAvatar(name: job.technician!.name, url: job.technician!.avatar, size: 26),
                      const SizedBox(width: 8),
                      Expanded(child: Text(job.technician!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ] else ...[
                      AppAvatar(name: job.client.name, url: job.client.avatar, size: 26),
                      const SizedBox(width: 8),
                      Expanded(child: Text(job.client.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                    Icon(Icons.chevron_right_rounded, color: p.subtle),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Technician list row (directory).
class TechnicianCard extends StatelessWidget {
  final User tech;
  final VoidCallback? onTap;
  const TechnicianCard({super.key, required this.tech, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppAvatar(name: tech.name, url: tech.avatar, size: 56, online: tech.online),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: Text(tech.name, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 15))),
                      if (tech.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 16)],
                    ]),
                    if (tech.headline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(tech.headline,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RatingLabel(rating: tech.rating, count: tech.ratingCount),
                        if (tech.jobsCompleted > 0) _meta(context, Icons.task_alt_rounded, '${tech.jobsCompleted} jobs'),
                        if (tech.city.isNotEmpty) _meta(context, Icons.place_outlined, tech.city),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (tech.hourlyRate > 0) ...[
                    Text(Fmt.money(tech.hourlyRate), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                    Text('per hour', style: TextStyle(fontSize: 11, color: p.subtle)),
                  ],
                  const SizedBox(height: 6),
                  if (!tech.isAvailable) Pill('Busy', color: p.subtle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.palette.subtle),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 12.5, color: context.palette.muted)),
        ],
      );
}

/// Square-ish technician card for horizontal carousels.
class TechnicianTile extends StatelessWidget {
  final User tech;
  final VoidCallback? onTap;
  const TechnicianTile({super.key, required this.tech, this.onTap});

  @override
  Widget build(BuildContext context) {
    final skill = tech.skills.isNotEmpty ? Catalog.service(tech.skills.first) : null;
    return SizedBox(
      width: 156,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(name: tech.name, url: tech.avatar, size: 52, online: tech.online, verified: tech.isVerified),
                const SizedBox(height: 12),
                Text(tech.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(skill?.label ?? 'Technician', maxLines: 1, style: TextStyle(fontSize: 12.5, color: context.palette.muted)),
                const Spacer(),
                RatingLabel(rating: tech.rating, count: tech.ratingCount, size: 12.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marketplace tool card for grids.
class ToolCard extends StatelessWidget {
  final Tool tool;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ToolCard({super.key, required this.tool, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cat = Catalog.tool(tool.category);
    final p = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(tool.coverImage, placeholder: cat),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: !tool.available
                        ? Pill('Unlisted', color: p.subtle, solid: true)
                        : tool.stock <= 0
                            ? Pill('Rented out', color: p.danger, solid: true)
                            : const SizedBox.shrink(),
                  ),
                  if (tool.hasInstallments)
                    const Positioned(right: 8, top: 8, child: Pill('Installments', color: Brand.accent, solid: true)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(Fmt.money(tool.rentPricePerDay), style: TextStyle(fontWeight: FontWeight.w800, color: context.colors.primary)),
                      Text(' /day', style: TextStyle(fontSize: 12, color: p.muted)),
                      const Spacer(),
                      if (trailing != null)
                        trailing!
                      else if (tool.ratingCount > 0)
                        RatingLabel(rating: tool.rating, count: tool.ratingCount, size: 11.5),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rental / purchase request row. [perspective] is 'renter' or 'supplier'.
class RentalCard extends StatelessWidget {
  final Rental rental;
  final String perspective;
  final List<Widget> actions;
  final VoidCallback? onTap;

  const RentalCard({super.key, required this.rental, required this.perspective, this.actions = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = rental;
    final other = perspective == 'supplier' ? r.renter : r.supplier;
    final period = r.isInstallment
        ? '${r.monthsRemaining} monthly payments'
        : '${Fmt.shortDate(r.startDate)} → ${Fmt.shortDate(r.endDate)} · ${Fmt.plural(r.days, 'day')}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: NetImage(r.tool.image, width: 56, height: 56, placeholder: Catalog.tool(r.tool.category)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.tool.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(period, style: TextStyle(fontSize: 12.5, color: p.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.money(r.totalCost), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                      if (r.deposit > 0) Text('+ ${Fmt.money(r.deposit)} deposit', style: TextStyle(fontSize: 11, color: p.subtle)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusPill(r.status),
                  Pill(r.isInstallment ? 'Installments' : 'Rental',
                      color: r.isInstallment ? Brand.accent : p.info,
                      icon: r.isInstallment ? Icons.payments_outlined : Icons.schedule_rounded),
                  if (r.overdue) Pill('Overdue', color: p.danger, icon: Icons.warning_amber_rounded, solid: true),
                  if (!r.overdue && r.daysLeft != null && r.status == 'active')
                    Pill(r.daysLeft! <= 0 ? 'Due today' : '${Fmt.plural(r.daysLeft!, 'day')} left', color: p.warning),
                  if (!r.isInstallment)
                    Pill(r.fulfillment == 'delivery' ? 'Delivery' : 'Pickup',
                        color: p.muted, icon: r.fulfillment == 'delivery' ? Icons.local_shipping_outlined : Icons.storefront_outlined),
                ],
              ),
              if (other != null && other.name.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  AppAvatar(name: other.name, url: other.avatar, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${perspective == 'supplier' ? 'Requested by' : 'From'} ${other.name}${(other.phone ?? '').isNotEmpty && r.status == 'active' ? ' · ${other.phone}' : ''}',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ),
                ]),
              ],
              if (r.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('“${r.note}”', style: TextStyle(fontStyle: FontStyle.italic, color: p.muted, fontSize: 13)),
              ],
              if (r.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.rejectionReason, style: TextStyle(color: p.danger, fontSize: 13)),
              ],
              if (r.rating != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  RatingStars(value: r.rating!, size: 15),
                  if (r.review.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(r.review, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13))),
                  ],
                ]),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
