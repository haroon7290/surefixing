import 'package:flutter/material.dart';

import '../../kit.dart';
import '../account/edit_profile_screen.dart';
import '../rentals/rentals_screens.dart';
import '../shell/shell.dart';
import '../tools/tool_form_screen.dart';
import '../tools/tool_widgets.dart';
import 'home_widgets.dart';

class _Data {
  final Json summary;
  final List<Rental> rentals;
  const _Data(this.summary, this.rentals);
}

/// The supplier's dashboard: revenue, requests to approve, tools out on
/// rent and installment plans.
class SupplierHome extends StatefulWidget {
  const SupplierHome({super.key});

  @override
  State<SupplierHome> createState() => _SupplierHomeState();
}

class _SupplierHomeState extends State<SupplierHome> {
  final _view = GlobalKey<AsyncViewState<_Data>>();

  Future<_Data> _load() async {
    final results = await Future.wait([
      Api.map('/api/users/me/summary'),
      Api.list('/api/rentals', query: {'as': 'supplier', 'status': 'requested,active'}),
    ]);
    return _Data(results[0] as Json, (results[1] as List<Json>).map(Rental.fromJson).toList());
  }

  void _reload() => _view.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return AppPage(
      body: AsyncView<_Data>(
        key: _view,
        load: _load,
        events: const {...Live.rentals, ...Live.wallet},
        builder: (context, d) => ListenableBuilder(
          listenable: Session.instance,
          builder: (context, _) {
            final me = Session.instance.user!;
            final s = d.summary;
            final byStatus = asJson(s['rentals']);
            final requested = d.rentals.where((r) => r.requested).toList();
            final active = d.rentals.where((r) => r.active).toList()..sort((a, b) => (b.overdue ? 1 : 0) - (a.overdue ? 1 : 0));

            final hero = EarningsHero(
              label: 'Total revenue',
              amount: dbl(s['revenue']),
              caption: 'From approved rentals and installment sales',
              figures: [
                HeroFigure(label: 'Wallet', value: moneyCompact(me.walletBalance), icon: AppIcons.wallet, onTap: () => openSection(context, 'wallet')),
                HeroFigure(label: 'Tools listed', value: '${integer(s['tools'])}', icon: AppIcons.tools, onTap: () => openSection(context, 'inventory')),
                HeroFigure(label: 'Out now', value: '${integer(byStatus['active'])}', icon: AppIcons.orders, onTap: () => openSection(context, 'orders')),
              ],
            );
            final stats = [
              StatCard(label: 'Waiting for approval', value: '${integer(byStatus['requested'])}', icon: AppIcons.hourglass, tone: Tone.warning, onTap: () => openSection(context, 'orders')),
              StatCard(label: 'Finished rentals', value: '${integer(byStatus['returned']) + integer(byStatus['completed'])}', icon: AppIcons.success, tone: Tone.success, onTap: () => openSection(context, 'orders')),
            ];

            return PageList(
              onRefresh: () => _view.currentState!.reload(),
              children: [
                HomeHeader(
                  subtitle: 'Your rental business at a glance.',
                  actions: [
                    Btn(wide ? 'Add a tool' : 'Add', icon: AppIcons.add, size: wide ? BtnSize.md : BtnSize.sm, onPressed: () async {
                      await push(context, const ToolFormScreen());
                      _reload();
                    }),
                  ],
                ),
                if (me.address.isEmpty) ...[
                  Notice(
                    'Customers who choose pickup need to know where to collect. Add your shop or pickup address before approving requests.',
                    title: 'Add your pickup address',
                    tone: Tone.warning,
                    action: Btn('Add address', kind: BtnKind.dark, size: BtnSize.sm, onPressed: () => push(context, const EditProfileScreen())),
                  ),
                  Gap.h12,
                ],
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 7, child: hero),
                    Gap.w16,
                    Expanded(flex: 4, child: Column(children: [stats[0], Gap.h16, stats[1]])),
                  ])
                else ...[
                  hero,
                  Gap.h12,
                  Row(children: [Expanded(child: stats[0]), Gap.w12, Expanded(child: stats[1])]),
                ],
                SectionTitle('Waiting for your approval', action: 'All orders', onAction: () => openSection(context, 'orders')),
                if (requested.isEmpty)
                  const Panel(child: EmptyState(compact: true, icon: AppIcons.orders, title: 'No new requests', message: 'Rental and purchase requests show up here as they arrive.'))
                else
                  AutoGrid(minWidth: 340, gap: 12, maxColumns: 2, children: [
                    for (final r in requested)
                      RentalCard(r, forSupplier: true, onTap: () => openRental(context, r, forSupplier: true, onChanged: _reload), actions: supplierActions(context, r, _reload)),
                  ]),
                if (active.isNotEmpty) ...[
                  const SectionTitle('Out with customers'),
                  AutoGrid(minWidth: 340, gap: 12, maxColumns: 2, children: [
                    for (final r in active)
                      RentalCard(r, forSupplier: true, onTap: () => openRental(context, r, forSupplier: true, onChanged: _reload), actions: supplierActions(context, r, _reload)),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
