import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../jobs/job_detail_parts.dart';
import '../shell/shell.dart';
import '../tools/tool_widgets.dart';

// ------------------------------------------------------------- actions

Future<bool> _call(Future<dynamic> Function() call, {String? done}) async {
  try {
    await call();
    if (done != null) toastOk(done);
    Session.instance.refresh();
    return true;
  } on ApiError catch (e) {
    e.insufficientFunds ? toast(e.message, kind: ToastKind.error, actionLabel: 'Add funds', onAction: () => openSection(navigatorKey.currentContext!, 'wallet')) : toastError(e);
    return false;
  } catch (e) {
    toastError(e);
    return false;
  }
}

Future<void> _approve(BuildContext context, Rental r, VoidCallback onChanged) async {
  if (await _call(() => Api.post('/api/rentals/${r.id}/approve'), done: 'Approved — ${r.renter.firstName} now has the handover details')) onChanged();
}

Future<void> _decline(BuildContext context, Rental r, VoidCallback onChanged) async {
  final reason = await promptText(context,
      title: 'Decline this request?',
      message: r.payment.held ? 'The customer is refunded in full.' : null,
      label: 'Reason',
      hint: 'e.g. Already booked for those dates',
      confirmLabel: 'Decline',
      danger: true);
  if (reason != null && await _call(() => Api.post('/api/rentals/${r.id}/reject', {'reason': reason}), done: 'Request declined')) onChanged();
}

Future<void> _markReturned(BuildContext context, Rental r, VoidCallback onChanged) async {
  final ok = await confirm(
    context,
    title: 'Is the tool back?',
    message: r.overdue
        ? 'It is ${plural(r.lateDays, 'day')} late: ${money(r.lateFee)} is taken from the deposit and paid to you. The rest of the deposit goes back to the customer.'
        : 'This puts it back in stock, pays you, and returns the deposit to the customer.',
    confirmLabel: 'Mark returned',
    icon: AppIcons.success,
  );
  if (ok && await _call(() => Api.post('/api/rentals/${r.id}/return'), done: 'Marked as returned')) onChanged();
}

Future<void> _recordInstallment(BuildContext context, Rental r, VoidCallback onChanged, {bool all = false}) async {
  final ok = await confirm(
    context,
    title: all ? 'Mark as fully paid?' : 'Record a cash payment?',
    message: all ? 'Use this when the customer has paid the whole remaining amount.' : 'Record month ${r.monthsPaid + 1} of ${r.monthsTotal} (${money(r.monthlyAmount)}) as paid in cash.',
    confirmLabel: all ? 'Fully paid' : 'Record payment',
    icon: AppIcons.cash,
  );
  if (ok && await _call(() => Api.post('/api/rentals/${r.id}/record-installment', {'all': all}), done: 'Payment recorded')) onChanged();
}

/// Quick actions a supplier gets on a rental card.
List<Widget> supplierActions(BuildContext context, Rental r, VoidCallback onChanged) => [
      if (r.requested) ...[
        Btn('Decline', kind: BtnKind.outline, size: BtnSize.sm, expand: true, onPressed: () => _decline(context, r, onChanged)),
        Btn('Approve', icon: AppIcons.check, size: BtnSize.sm, expand: true, onPressed: () => _approve(context, r, onChanged)),
      ] else if (r.active && !r.isInstallment)
        Btn('Mark returned', icon: AppIcons.check, kind: BtnKind.dark, size: BtnSize.sm, expand: true, onPressed: () => _markReturned(context, r, onChanged))
      else if (r.active && r.isInstallment)
        Btn('Record cash payment', icon: AppIcons.cash, kind: BtnKind.dark, size: BtnSize.sm, expand: true, onPressed: () => _recordInstallment(context, r, onChanged)),
    ];

Future<void> openRental(BuildContext context, Rental r, {required bool forSupplier, VoidCallback? onChanged}) async {
  await push(context, RentalDetailScreen(rentalId: r.id, forSupplier: forSupplier));
  onChanged?.call();
}

// --------------------------------------------------------------- lists

class _RentalList extends StatefulWidget {
  final bool forSupplier;
  const _RentalList({required this.forSupplier});

  @override
  State<_RentalList> createState() => _RentalListState();
}

class _RentalListState extends State<_RentalList> {
  final _view = GlobalKey<AsyncViewState<List<Rental>>>();
  String _filter = 'open';

  void _reload() => _view.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final supplier = widget.forSupplier;
    final filters = supplier
        ? const {'open': 'To do', 'requested': 'Requests', 'active': 'Out now', 'plans': 'Installments', 'history': 'History'}
        : const {'open': 'Current', 'plans': 'Installments', 'history': 'History'};
    bool match(Rental r, String key) => switch (key) {
          'requested' => r.requested,
          'active' => r.active && !r.isInstallment,
          'plans' => r.isInstallment && r.open,
          'history' => !r.open,
          _ => supplier ? (r.requested || (r.active && !r.isInstallment)) : (r.open && !r.isInstallment),
        };
    return AppPage(
      title: supplier ? 'Orders' : 'My rentals',
      subtitle: supplier ? 'Approve requests, take tools back and track installment plans.' : 'Tools you rented or are buying in installments.',
      actions: [
        if (!supplier)
          Btn(context.isWide ? 'Browse tools' : 'Browse', icon: AppIcons.tools, kind: BtnKind.soft, size: context.isWide ? BtnSize.md : BtnSize.sm, onPressed: () => openSection(context, 'tools'))
      ],
      body: AsyncView<List<Rental>>(
        key: _view,
        load: () async => (await Api.list('/api/rentals', query: {'as': supplier ? 'supplier' : 'renter', 'limit': 100})).map(Rental.fromJson).toList(),
        events: Live.rentals,
        builder: (context, all) {
          final items = all.where((r) => match(r, _filter)).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PagePad(
              child: Pills<String>(
                scroll: true,
                values: filters.keys.toList(),
                label: (k) {
                  final n = all.where((r) => match(r, k)).length;
                  return n == 0 || k == 'history' ? filters[k]! : '${filters[k]} · $n';
                },
                selected: _filter,
                onTap: (k) => setState(() => _filter = k),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: supplier ? AppIcons.orders : AppIcons.rentals,
                      title: all.isEmpty ? (supplier ? 'No orders yet' : 'No rentals yet') : 'Nothing here',
                      message:
                          all.isEmpty ? (supplier ? 'Requests from customers will appear here.' : 'Rent a drill for the weekend, or buy a tool in monthly payments.') : 'Nothing matches this filter.',
                      action: all.isEmpty && !supplier ? Btn('Browse tools', icon: AppIcons.tools, onPressed: () => openSection(context, 'tools')) : null,
                    )
                  : PageList(
                      onRefresh: () => _view.currentState!.reload(),
                      children: [
                        AutoGrid(minWidth: 360, gap: 12, maxColumns: 2, children: [
                          for (final r in items)
                            RentalCard(
                              r,
                              forSupplier: supplier,
                              onTap: () => openRental(context, r, forSupplier: supplier, onChanged: _reload),
                              actions: supplier
                                  ? supplierActions(context, r, _reload)
                                  : [
                                      if (r.isInstallment && r.active)
                                        Btn('Pay ${money(r.monthlyAmount)}',
                                            icon: AppIcons.wallet, size: BtnSize.sm, expand: true, onPressed: () => openRental(context, r, forSupplier: false, onChanged: _reload)),
                                      if (r.canReview)
                                        Btn('Leave a review',
                                            icon: AppIcons.star, kind: BtnKind.dark, size: BtnSize.sm, expand: true, onPressed: () => openRental(context, r, forSupplier: false, onChanged: _reload)),
                                    ],
                            ),
                        ]),
                      ],
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

/// The renter's rentals and installment plans.
class MyRentalsScreen extends StatelessWidget {
  const MyRentalsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RentalList(forSupplier: false);
}

/// The supplier's incoming requests, tools out, and plans.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RentalList(forSupplier: true);
}

// -------------------------------------------------------------- detail

/// Everything about one rental or installment plan, with the actions that
/// make sense for whoever is looking.
class RentalDetailScreen extends StatefulWidget {
  final String rentalId;
  final bool forSupplier;
  const RentalDetailScreen({super.key, required this.rentalId, required this.forSupplier});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Rental>>();
  bool _busy = false;

  void _reload() => _view.currentState?.reload();

  Future<void> _do(Future<dynamic> Function() call, String done) async {
    setState(() => _busy = true);
    if (await _call(call, done: done)) _reload();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => AsyncView<Rental>(
        key: _view,
        load: () async => Rental.fromJson(await Api.map('/api/rentals/${widget.rentalId}')),
        events: Live.rentals,
        loading: const AppPage(title: 'Rental', body: SkeletonList()),
        builder: (context, r) => _body(context, r),
      );

  Widget _body(BuildContext context, Rental r) {
    final c = context.colors;
    final supplier = widget.forSupplier;
    final other = supplier ? r.renter : r.supplier;
    final status = rentalStatus(r.status, installment: r.isInstallment, overdue: r.overdue);
    final cat = toolCategory(r.tool.category);
    final h = r.handover;

    final head = Panel(
      onTap: supplier ? null : () => openTool(context, r.tool.id),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(R.md), child: SizedBox.square(dimension: 76, child: CoverImage(r.tool.image, category: cat, iconSize: 30))),
        Gap.w12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(r.tool.name.isEmpty ? 'Tool' : r.tool.name, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            Gap.h6,
            Wrap(spacing: 6, runSpacing: 6, children: [Pill.status(status), Pill(r.isInstallment ? 'Installment purchase' : 'Rental')]),
          ]),
        ),
      ]),
    );

    final what = switch (r.status) {
      'requested' => supplier
          ? Notice('${r.renter.firstName} is waiting for your answer.${r.payment.held ? ' Their payment is already in escrow.' : ''}',
              title: 'New request',
              tone: Tone.brand,
              action: Wrap(spacing: 8, runSpacing: 8, children: [
                Btn('Approve', icon: AppIcons.check, size: BtnSize.sm, onPressed: _busy ? null : () => _approve(context, r, _reload)),
                Btn('Decline', kind: BtnKind.outline, size: BtnSize.sm, onPressed: _busy ? null : () => _decline(context, r, _reload)),
              ]))
          : Notice('The supplier will approve or decline soon. You will get the handover details once approved.',
              title: 'Waiting for approval',
              tone: Tone.info,
              action: Btn('Cancel request',
                  kind: BtnKind.outline,
                  size: BtnSize.sm,
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await confirm(context,
                              title: 'Cancel this request?',
                              message: r.payment.held ? 'Your payment is refunded in full.' : null,
                              confirmLabel: 'Cancel request',
                              cancelLabel: 'Keep it',
                              danger: true)) {
                            _do(() => Api.post('/api/rentals/${r.id}/cancel'), 'Request cancelled');
                          }
                        })),
      'active' when r.isInstallment => null,
      'active' => r.overdue
          ? Notice(
              supplier
                  ? 'Due back ${shortDate(r.endDate)}. Late fee so far: ${money(r.lateFee)}, taken from the deposit when you mark it returned.'
                  : 'It was due back ${shortDate(r.endDate)}. Each late day costs ${money(r.dailyRate)} from your deposit — ${money(r.lateFee)} so far.',
              title: '${plural(r.lateDays, 'day')} overdue',
              tone: Tone.danger,
              action: supplier ? Btn('Mark returned', icon: AppIcons.check, kind: BtnKind.dark, size: BtnSize.sm, onPressed: _busy ? null : () => _markReturned(context, r, _reload)) : null,
            )
          : Notice(
              supplier ? 'Due back ${longDate(r.endDate)}. Mark it returned when you have it.' : 'Return it by ${longDate(r.endDate)} to get your full deposit back.',
              title: r.daysLeft != null && r.daysLeft! <= 0 ? 'Due back today' : 'Out on rent — ${plural(r.daysLeft ?? 0, 'day')} left',
              tone: Tone.brand,
              icon: AppIcons.timer,
              action: supplier ? Btn('Mark returned', icon: AppIcons.check, kind: BtnKind.dark, size: BtnSize.sm, onPressed: _busy ? null : () => _markReturned(context, r, _reload)) : null,
            ),
      'returned' => Notice(
          r.lateFee > 0
              ? 'Returned ${plural(r.lateDays, 'day')} late. A ${money(r.lateFee)} late fee came out of the deposit.'
              : 'Returned on time${r.payment.isWallet && r.deposit > 0 ? ' — the deposit was refunded' : ''}.',
          title: 'Rental finished',
          tone: Tone.success,
        ),
      'completed' => const Notice('Every installment is paid. The tool belongs to the customer.', title: 'Paid off', tone: Tone.success),
      'rejected' => Notice(r.rejectionReason.isEmpty ? 'The supplier could not accept this request.' : r.rejectionReason, title: 'Request declined', tone: Tone.danger),
      _ => Notice(r.rejectionReason.isEmpty ? 'This request was cancelled.' : r.rejectionReason, title: 'Cancelled', tone: Tone.neutral),
    };

    final plan = !r.isInstallment || !(r.active || r.status == 'completed')
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('Payment plan', style: context.text.titleMedium)),
                Text('${r.monthsPaid} / ${r.monthsTotal} months', style: context.text.titleSmall),
              ]),
              Gap.h12,
              ProgressLine(r.monthsTotal == 0 ? 0 : r.monthsPaid / r.monthsTotal, height: 8),
              Gap.h12,
              KV('Monthly payment', money(r.monthlyAmount)),
              KV('Paid so far', money(r.monthsPaid * r.monthlyAmount)),
              KV('Remaining', money(r.monthsRemaining * r.monthlyAmount), strong: true),
              if (r.active) ...[
                Gap.h12,
                if (supplier) ...[
                  Btn('Record a cash payment', icon: AppIcons.cash, kind: BtnKind.dark, expand: true, onPressed: _busy ? null : () => _recordInstallment(context, r, _reload)),
                  Gap.h8,
                  Btn('Mark as fully paid', kind: BtnKind.outline, expand: true, onPressed: _busy ? null : () => _recordInstallment(context, r, _reload, all: true)),
                ] else ...[
                  Btn('Pay month ${r.monthsPaid + 1} · ${money(r.monthlyAmount)}', icon: AppIcons.wallet, size: BtnSize.lg, expand: true, loading: _busy, onPressed: () async {
                    if (await confirm(context,
                        title: 'Pay ${money(r.monthlyAmount)} from your wallet?',
                        message: 'Month ${r.monthsPaid + 1} of ${r.monthsTotal} for ${r.tool.name}.',
                        confirmLabel: 'Pay now',
                        icon: AppIcons.wallet)) {
                      _do(() => Api.post('/api/rentals/${r.id}/pay-installment'), 'Installment paid');
                    }
                  }),
                  Gap.h8,
                  Text('Paying in cash instead? The supplier records it on their side.', textAlign: TextAlign.center, style: context.text.bodySmall),
                ],
              ],
            ]),
          );

    final money_ = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(r.isInstallment ? 'Purchase' : 'Rental', style: context.text.titleMedium)),
          if (r.payment.exists) Pill.status(paymentStatus(r.payment.status)),
        ]),
        Gap.h8,
        if (r.isInstallment) ...[
          KV('Full price', money(r.totalCost)),
          KV('Plan', '${r.monthsTotal} × ${money(r.monthlyAmount)}'),
        ] else ...[
          KV('Dates', '${shortDate(r.startDate)} → ${shortDate(r.endDate)}', icon: AppIcons.calendar),
          KV('${money(r.dailyRate)} × ${plural(r.days, 'day')}', money(r.totalCost)),
          if (r.deposit > 0) KV('Deposit (refundable)', money(r.deposit)),
          if (r.lateFee > 0) KV('Late fee', money(r.lateFee), valueColor: c.danger),
          const Divider(),
          KV('Paid by', r.payment.isWallet ? 'SureFix Wallet' : 'Cash', strong: true),
          if (supplier && r.payment.isWallet && r.payment.fee > 0) ...[
            KV('SureFix fee', '− ${money(r.payment.fee)}'),
            KV('You receive', money(r.payment.net + r.lateFee), strong: true),
          ],
        ],
        if (r.note.isNotEmpty) ...[const Divider(), Gap.h4, Text('Note: ${r.note}', style: context.text.bodyMedium)],
      ]),
    );

    final handover = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconTile(h.delivery ? AppIcons.truck : AppIcons.store, tone: Tone.brand, size: 40),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(h.delivery ? 'Delivery' : 'Pickup', style: context.text.titleMedium),
              Text(h.delivery ? (supplier ? 'Deliver the tool to the customer' : 'The supplier brings it to you') : (supplier ? 'The customer collects from you' : 'Collect it from the supplier'),
                  style: context.text.bodySmall),
            ]),
          ),
        ]),
        Gap.h12,
        if (h.address.isNotEmpty)
          _CopyLine(icon: AppIcons.pin, text: h.address, what: 'Address')
        else
          Text(
            h.revealed
                ? 'No address was given — message ${other.firstName} to arrange it.'
                : 'In ${h.city.isEmpty ? 'the supplier\'s city' : h.city}. The exact address is shared once the request is approved.',
            style: context.text.bodyMedium,
          ),
      ]),
    );

    final person = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(supplier ? 'Customer' : 'Supplier', style: context.text.bodySmall),
        Gap.h8,
        PersonRow(name: other.name, image: other.avatar, verified: other.verified, subtitle: other.city, size: 46),
        if (other.phone.isNotEmpty) ...[Gap.h12, _CopyLine(icon: AppIcons.phone, text: other.phone, what: 'Phone number')],
        Gap.h12,
        Btn('Message ${other.firstName}',
            icon: AppIcons.chat,
            kind: BtnKind.dark,
            expand: true,
            onPressed: () => openChat(context, ChatTarget(toolId: r.tool.id, otherId: other.id, otherName: other.name, otherAvatar: other.avatar, subject: r.tool.name))),
      ]),
    );

    final review = r.rating != null
        ? Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Expanded(child: Text(supplier ? 'Customer review' : 'Your review', style: context.text.titleMedium)), Stars(r.rating!.toDouble(), size: 18)]),
              if (r.review.isNotEmpty) ...[Gap.h8, Text('"${r.review}"', style: context.text.bodyLarge!.copyWith(fontSize: 15))],
            ]),
          )
        : (!supplier && r.canReview
            ? Notice('How was the tool? Your review helps other renters.',
                title: 'Leave a review',
                tone: Tone.brand,
                icon: AppIcons.starFill,
                action: Btn('Rate this tool',
                    size: BtnSize.sm,
                    kind: BtnKind.dark,
                    onPressed: _busy
                        ? null
                        : () async {
                            final res = await showRateSheet(context, name: r.tool.name);
                            if (res != null) _do(() => Api.post('/api/rentals/${r.id}/review', res), 'Thanks for your review');
                          }))
            : null);

    Widget gap(Widget? w) => w == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: w);
    return AppPage(
      title: r.isInstallment ? 'Installment plan' : 'Rental',
      maxWidth: 1000,
      body: PageList(onRefresh: () => _view.currentState!.reload(), children: [
        TwoCol(
          main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [gap(head), gap(what), gap(plan), gap(review), gap(money_)]),
          side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [gap(handover), gap(person)]),
        ),
      ]),
    );
  }
}

class _CopyLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String what;
  const _CopyLine({required this.icon, required this.text, required this.what});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Copy $what: $text',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(R.sm),
        onTap: () {
          Clipboard.setData(ClipboardData(text: text));
          toast('$what copied');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.sm)),
          child: Row(children: [
            Icon(icon, size: 16, color: c.body),
            Gap.w8,
            Expanded(child: Text(text, style: context.text.titleSmall)),
            Icon(AppIcons.copy, size: 15, color: c.muted),
          ]),
        ),
      ),
    );
  }
}
