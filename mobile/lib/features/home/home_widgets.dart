import 'package:flutter/material.dart';

import '../../kit.dart';
import '../shell/shell.dart';

/// Top of every dashboard: avatar, greeting, and the notification bell
/// (the website has those in the sidebar, so it shows a bigger heading).
class HomeHeader extends StatelessWidget {
  final String? subtitle;
  final List<Widget> actions;
  const HomeHeader({super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          final user = Session.instance.user;
          if (user == null) return const SizedBox.shrink();
          final wide = context.isWide;
          return Padding(
            padding: EdgeInsets.only(top: wide ? 28 : 8, bottom: wide ? 24 : 18),
            child: Row(children: [
              if (!wide) ...[
                Semantics(
                  button: true,
                  label: 'Account',
                  excludeSemantics: true,
                  child: GestureDetector(onTap: () => openSection(context, 'account'), child: Avatar(name: user.name, image: user.avatar, size: 46)),
                ),
                Gap.w12,
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (!wide) Text('${greeting()},', style: context.text.bodySmall!.copyWith(fontSize: 13)),
                  Text(
                    wide ? '${greeting()}, ${user.firstName}' : user.firstName,
                    style: wide ? context.text.headlineLarge : context.text.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (wide && subtitle != null) ...[Gap.h4, Text(subtitle!, style: context.text.bodyLarge)],
                ]),
              ),
              for (final a in actions) ...[Gap.w8, a],
              if (!wide) ...[
                Gap.w8,
                ValueListenableBuilder<int>(
                  valueListenable: Badges.instance.notifications,
                  builder: (context, n, _) => RoundBtn(AppIcons.bell, tooltip: 'Notifications', badge: n, onPressed: () => openSection(context, 'notifications')),
                ),
              ],
            ]),
          );
        },
      );
}

/// A horizontally scrolling row of cards that bleeds to the screen edge on
/// phones.
class HScroll extends StatelessWidget {
  final double height;
  final List<Widget> children;
  const HScroll({super.key, required this.height, required this.children});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          separatorBuilder: (_, __) => Gap.w12,
          itemBuilder: (_, i) => children[i],
        ),
      );
}

/// A figure inside a dark hero card.
class HeroFigure extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const HeroFigure({super.key, required this.label, required this.value, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.onHero.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(R.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c.brand),
            Gap.h8,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: TextStyle(fontFamily: kDisplayFont, fontSize: 18, fontWeight: FontWeight.w700, color: c.onHero, letterSpacing: -0.3, height: 1.2)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kBodyFont, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.onHeroMuted)),
          ]),
        ),
      ),
    );
  }
}

/// The big earnings / revenue card on technician and supplier dashboards.
class EarningsHero extends StatelessWidget {
  final String label;
  final double amount;
  final String? caption;
  final List<HeroFigure> figures;
  const EarningsHero({super.key, required this.label, required this.amount, this.caption, required this.figures});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.onHeroMuted)),
        Gap.h6,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(money(amount), style: context.text.displayMedium!.copyWith(color: c.onHero)),
        ),
        if (caption != null) ...[Gap.h4, Text(caption!, style: context.text.bodySmall!.copyWith(color: c.onHeroMuted))],
        Gap.h20,
        Row(children: [
          for (var i = 0; i < figures.length; i++) ...[if (i > 0) Gap.w8, Expanded(child: figures[i])],
        ]),
      ]),
    );
  }
}
