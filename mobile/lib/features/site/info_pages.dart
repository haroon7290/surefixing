import 'package:flutter/material.dart';

import '../../kit.dart';
import 'content.dart';
import 'landing_page.dart';

/// "How it works": what each kind of member does on SureFix.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _roles = [
    (
      'For customers',
      AppIcons.home,
      'client',
      'Create a free account',
      [
        ('Post a job in a minute', 'Describe the problem and add photos. The AI suggests the trade, urgency and a fair price range.'),
        ('Choose with confidence', 'Compare quotes ranked by match score, read reviews, chat before you hire.'),
        ('Stay in control', 'Pay into escrow or in cash, follow progress live, and confirm only when you are happy.'),
      ]
    ),
    (
      'For technicians',
      AppIcons.technicians,
      'technician',
      'Become a technician',
      [
        ('Find work that fits', 'Browse open jobs that match your skills and city, or receive direct requests.'),
        ('Win on quality', 'A verified badge, a portfolio and real reviews lift your match score.'),
        ('Get paid on time', 'Escrow means the money is already there. It lands in your wallet when the customer confirms.'),
      ]
    ),
    (
      'For tool suppliers',
      AppIcons.tools,
      'supplier',
      'List your tools',
      [
        ('List in minutes', 'Add photos, a daily rate, a deposit and stock. Offer monthly installments if you sell.'),
        ('Approve each request', 'You decide who rents. Stock is reserved automatically and released on return.'),
        ('Protected rentals', 'Deposits cover late returns, and wallet payments are settled the moment a tool is back.'),
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'How SureFix works',
      subtitle: 'One marketplace for getting things fixed and renting the tools to do it yourself.',
      body: PageList(children: [
        for (final (title, icon, role, cta, points) in _roles) ...[
          Panel(
            padding: EdgeInsets.all(context.isWide ? 28 : 18),
            child: TwoCol(
              sideWidth: 300,
              sideFirstOnPhone: true,
              side: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                IconTile(icon, tone: Tone.brand, size: 52),
                Gap.h16,
                Text(title, style: context.text.headlineMedium),
                Gap.h16,
                Btn(cta, kind: BtnKind.dark, trailing: AppIcons.forward, onPressed: () {
                  SiteNav.signupRole = role;
                  SiteNav.go('register');
                }),
              ]),
              main: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < points.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: context.text.titleSmall!.copyWith(color: c.brandDeep)),
                      ),
                      Gap.w12,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(points[i].$1, style: context.text.titleMedium),
                          Gap.h4,
                          Text(points[i].$2, style: context.text.bodyMedium!.copyWith(fontSize: 14.5)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          Gap.h16,
        ],
        const SectionTitle('Common questions'),
        const FaqList(limit: 4),
      ]),
    );
  }
}

/// Help centre: every question, plus how to reach support.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(
        title: 'Help & FAQ',
        subtitle: 'Payments, rentals, verification and what to do when something goes wrong.',
        maxWidth: 820,
        body: PageList(children: [
          FaqList(),
          Gap.h16,
          Notice(
            'Open the job or tool and choose "Report a problem". An admin reviews every report and can refund or release a payment held in escrow.',
            title: 'Something went wrong with a job or rental?',
            tone: Tone.brand,
            icon: AppIcons.help,
          ),
        ]),
      );
}

/// Terms of use / privacy notice.
class LegalPage extends StatelessWidget {
  final bool privacy;
  const LegalPage({super.key, this.privacy = false});

  @override
  Widget build(BuildContext context) => AppPage(
        title: privacy ? 'Privacy' : 'Terms of use',
        subtitle: privacy ? 'What SureFix stores about you and who can see it.' : 'The rules everyone on SureFix agrees to.',
        maxWidth: 820,
        body: PageList(children: [
          Panel(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (final (i, (title, body)) in (privacy ? privacySections : termsSections).indexed) ...[
                if (i > 0) Gap.h20,
                Text(title, style: context.text.titleLarge),
                Gap.h6,
                Text(body, style: context.text.bodyMedium!.copyWith(fontSize: 14.5)),
              ],
            ]),
          ),
        ]),
      );
}
