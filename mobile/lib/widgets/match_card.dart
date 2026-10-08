import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/recommendation.dart';
import 'app_avatar.dart';
import 'pills.dart';
import 'rating_stars.dart';
import 'visuals.dart';

/// An AI-ranked technician (Smart Match) or quote (ranked bids), with the
/// match gauge and the model's plain-English reasons.
class MatchCard extends StatelessWidget {
  final TechMatch match;
  final int rank;
  final bool showQuote;
  final bool highlight;
  final VoidCallback? onTap;
  final List<Widget> actions;

  const MatchCard({
    super.key,
    required this.match,
    required this.rank,
    this.showQuote = false,
    this.highlight = false,
    this.onTap,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final m = match;
    final p = context.palette;
    final best = rank == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: highlight || best ? context.colors.primary.withValues(alpha: 0.55) : p.border, width: highlight || best ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (best)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: context.colors.primary.withValues(alpha: 0.08),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 15, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(showQuote ? 'Best overall quote' : 'Best match',
                      style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(name: m.name, url: m.avatar, size: 52, online: m.online),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                  child: Text(m.name,
                                      overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 15.5))),
                              if (m.verified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 16)],
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              [if (m.headline.isNotEmpty) m.headline, if (m.city.isNotEmpty) m.city].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                            const SizedBox(height: 6),
                            Wrap(spacing: 10, runSpacing: 4, children: [
                              RatingLabel(rating: m.rating, count: m.ratingCount, size: 12.5),
                              if (m.jobsCompleted > 0) Text('${m.jobsCompleted} jobs', style: TextStyle(fontSize: 12.5, color: p.muted)),
                              Text('Replies ${Fmt.responseTime(m.avgResponseMinutes)}', style: TextStyle(fontSize: 12.5, color: p.muted)),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MatchRing(percent: m.matchPercent, size: 58),
                    ],
                  ),
                  if (showQuote) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(Fmt.money(m.amount),
                                style: context.text.titleLarge?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Icon(Icons.schedule_rounded, size: 16, color: p.muted),
                            const SizedBox(width: 4),
                            Text(m.etaDays == 0 ? 'Can start today' : 'Ready in ${Fmt.plural(m.etaDays, 'day')}',
                                style: TextStyle(color: p.muted, fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                          if (m.message.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('“${m.message}”', style: TextStyle(fontStyle: FontStyle.italic, color: p.muted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (m.reasons.isNotEmpty || m.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final r in m.reasons.take(3)) _line(context, Icons.check_circle_rounded, p.success, r, FontWeight.w600),
                    for (final n in m.notes.take(2)) _line(context, Icons.info_outline_rounded, p.warning, n, FontWeight.w500),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: actions[i])],
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, Color color, String text, FontWeight weight) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: weight))),
          ],
        ),
      );
}
