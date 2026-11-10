import 'package:flutter/material.dart';

import '../../kit.dart';

/// Heart toggle that saves a technician or tool to the user's favourites.
/// Signed-out visitors are sent to sign in.
class FavoriteButton extends StatelessWidget {
  final String type; // technician | tool
  final String id;
  final double size;
  final bool onImage;
  const FavoriteButton({super.key, required this.type, required this.id, this.size = 38, this.onImage = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          final c = context.colors;
          final session = Session.instance;
          if (session.loggedIn && !session.user!.isClient && !session.user!.isTechnician) return const SizedBox.shrink();
          final saved = session.isFavorite(type, id);
          return RoundBtn(
            saved ? AppIcons.heartFill : AppIcons.heart,
            tooltip: saved ? 'Remove from saved' : 'Save',
            size: size,
            color: saved ? c.danger : c.ink,
            background: onImage ? c.surface.withValues(alpha: 0.92) : null,
            bordered: !onImage,
            onPressed: () async {
              if (!session.loggedIn) {
                toast('Sign in to save your favourites');
                SiteNav.go('login');
                return;
              }
              try {
                final now = await session.toggleFavorite(type, id);
                toast(now ? 'Saved to your favourites' : 'Removed from saved', kind: ToastKind.success);
              } catch (e) {
                toastError(e);
              }
            },
          );
        },
      );
}

/// A technician in the directory.
class TechCard extends StatelessWidget {
  final User tech;
  final VoidCallback? onTap;
  final bool showFavorite;
  const TechCard(this.tech, {super.key, this.onTap, this.showFavorite = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: tech.name, image: tech.avatar, size: 54, online: tech.online),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(tech.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (tech.verified) ...[Gap.w4, const VerifiedTick()],
              ]),
              Gap.h2,
              Text(tech.headline.isEmpty ? 'Technician' : tech.headline, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Gap.h6,
              Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Rating(tech.rating, tech.ratingCount),
                if (tech.city.isNotEmpty) Meta(AppIcons.pin, tech.city),
              ]),
            ]),
          ),
          if (showFavorite) FavoriteButton(type: 'technician', id: tech.id, size: 36),
        ]),
        Gap.h12,
        SizedBox(
          height: 26,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final s in tech.skills.take(3)) Padding(padding: const EdgeInsets.only(right: 6), child: Pill(skillLabel(s))),
              if (tech.skills.length > 3) Pill('+${tech.skills.length - 3}'),
            ],
          ),
        ),
        Gap.h12,
        Divider(color: c.line),
        Gap.h12,
        Row(children: [
          Expanded(child: _Fact(count(tech.jobsCompleted), 'jobs done')),
          Expanded(child: _Fact(tech.experienceYears > 0 ? '${tech.experienceYears} yr' : '—', 'experience')),
          Expanded(child: _Fact(tech.hourlyRate > 0 ? money(tech.hourlyRate) : '—', 'per hour')),
        ]),
        if (!tech.isAvailable) ...[Gap.h12, const Pill('Busy right now', tone: Tone.warning, dot: true)],
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  final String value;
  final String label;
  const _Fact(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1),
      ]);
}

/// Compact technician tile for horizontal carousels.
class TechTile extends StatelessWidget {
  final User tech;
  final VoidCallback? onTap;
  const TechTile(this.tech, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 168,
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(name: tech.name, image: tech.avatar, size: 46, online: tech.online),
              const Spacer(),
              if (tech.verified) const VerifiedTick(size: 18),
            ]),
            Gap.h12,
            Text(tech.name, style: context.text.titleSmall!.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Gap.h2,
            Text(tech.headline.isEmpty ? (tech.skills.isEmpty ? 'Technician' : skillLabel(tech.skills.first)) : tech.headline,
                style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Rating(tech.rating, tech.ratingCount),
          ]),
        ),
      );
}

/// One written review.
class ReviewTile extends StatelessWidget {
  final Review review;
  const ReviewTile(this.review, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Avatar(name: review.author, image: review.authorAvatar, size: 34),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(review.author, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text([if (review.subject.isNotEmpty) review.subject, shortDate(review.at)].join('  ·  '),
                    style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Stars(review.rating.toDouble(), size: 13),
          ]),
          if (review.text.isNotEmpty) ...[Gap.h8, Text(review.text, style: context.text.bodyMedium)],
        ]),
      );
}
