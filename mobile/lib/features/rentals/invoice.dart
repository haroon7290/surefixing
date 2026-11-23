import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kit.dart';

/// The invoice for a rental or purchase: who sells to whom, what for, every
/// charge (rent or price, delivery, deposit, late fee, refunds), how it was
/// paid and, for the supplier, SureFix's fee and what they receive.
class RentalInvoice extends StatelessWidget {
  final Rental rental;
  final bool forSupplier;
  const RentalInvoice(this.rental, {super.key, required this.forSupplier});

  Rental get r => rental;

  /// Charged when the request was made: rent or price, plus delivery.
  double get _subtotal => r.amount;

  /// Late fee kept from the deposit (rentals), so far or final.
  double get _late => r.lateFee;

  bool get _returned => r.status == 'returned';

  /// What the customer pays in the end (the deposit comes back, minus the
  /// late fee).
  double get _finalCost => _subtotal + _late;

  bool get _closedEarly => r.status == 'rejected' || r.status == 'cancelled';

  String get _kind => r.isPurchase ? 'Purchase' : 'Rental';

  String _contact(User u, {String? address}) => [
        u.name,
        if (u.phone.isNotEmpty) u.phone,
        if (u.email.isNotEmpty) u.email,
        if ((address ?? '').isNotEmpty) address!,
        if (u.city.isNotEmpty && !(address ?? '').contains(u.city)) u.city,
      ].join('\n');

  /// Plain-text copy, to paste in a message or email.
  String asText() {
    final lines = <String>[
      'SureFix invoice ${r.invoiceNo}',
      'Date: ${longDate(r.createdAt)}',
      '$_kind: ${r.tool.name}',
      'Supplier: ${r.supplier.name}',
      'Customer: ${r.renter.name}',
      if (!r.isPurchase) 'Period: ${shortDate(r.startDate)} to ${shortDate(r.endDate)} (${plural(r.days, 'day')})',
      r.isPurchase ? 'Price: ${money(r.totalCost)}' : 'Rent: ${money(r.dailyRate)} x ${plural(r.days, 'day')} = ${money(r.totalCost)}',
      if (r.handover.delivery) 'Delivery: ${r.deliveryFee > 0 ? money(r.deliveryFee) : 'Free'}',
      'Subtotal: ${money(_subtotal)}',
      if (r.deposit > 0) 'Refundable deposit: ${money(r.deposit)}',
      if (_late > 0) 'Late fee (${plural(r.lateDays, 'day')}): ${money(_late)}',
      'Paid by: ${r.payment.isWallet ? 'SureFix Wallet' : 'Cash'} (${paymentStatus(r.payment.status).$1})',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = r.payment;
    final pay = paymentStatus(p.status);
    final wide = context.isWide;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(title.toUpperCase(), style: context.text.labelSmall!.copyWith(color: c.muted, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        );

    Widget party(String label, User u, {String? address}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: context.text.bodySmall),
          Gap.h4,
          Text(u.name.isEmpty ? '—' : u.name, style: context.text.titleSmall),
          for (final line in _contact(u, address: address).split('\n').skip(1)) Text(line, style: context.text.bodySmall!.copyWith(color: c.body)),
        ]);

    // Line item: description (with a detail line) and amount.
    Widget item(String what, String amount, {String? detail, Color? color, bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(what, style: strong ? context.text.titleSmall : context.text.bodyMedium),
                if (detail != null && detail.isNotEmpty) Text(detail, style: context.text.bodySmall),
              ]),
            ),
            Gap.w16,
            Text(amount, style: (strong ? context.text.titleMedium : context.text.titleSmall)!.copyWith(color: color ?? c.ink)),
          ]),
        );

    final supplierAddress = r.handover.delivery ? '' : r.handover.address;
    final customerAddress = r.handover.delivery ? r.handover.address : '';
    final parties = [
      party('From (supplier)', r.supplier, address: supplierAddress),
      party('Billed to (customer)', r.renter, address: customerAddress),
    ];

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // Header: number, date, payment state.
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Invoice', style: context.text.titleLarge),
              Gap.h2,
              Text([if (r.invoiceNo.isNotEmpty) r.invoiceNo, 'Issued ${longDate(r.createdAt)}'].join('  ·  '), style: context.text.bodySmall),
            ]),
          ),
          Pill.status(pay),
        ]),
        if (!r.contactShared) ...[
          Gap.h12,
          Text('Phone numbers and addresses appear here once the supplier approves.', style: context.text.bodySmall),
        ],
        section('Parties'),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final w in parties) Expanded(child: w)])
        else ...[parties[0], Gap.h12, parties[1]],

        section(r.isPurchase ? 'Purchase' : 'Rental'),
        KV('Tool', r.tool.name.isEmpty ? 'Tool' : r.tool.name),
        if (r.tool.condition.isNotEmpty) KV('Condition', toolConditions[r.tool.condition] ?? r.tool.condition),
        if (!r.isPurchase) ...[
          KV('Rental period', '${shortDate(r.startDate)} → ${shortDate(r.endDate)}'),
          KV('Length', plural(r.days, 'day')),
          if (r.returnedAt != null) KV('Returned', dateTime(r.returnedAt)),
        ],
        KV('Handover', r.handover.delivery ? 'Delivery to the customer' : 'Pickup from the supplier'),
        if (r.approvedAt != null) KV('Approved', dateTime(r.approvedAt)),
        if (r.isPurchase && r.completedAt != null) KV(r.handover.delivery ? 'Delivered' : 'Handed over', dateTime(r.completedAt)),

        section('Charges'),
        if (r.isPurchase)
          item('Tool price', money(r.totalCost), detail: 'One-time purchase')
        else
          item('Rent', money(r.totalCost), detail: '${money(r.dailyRate)} × ${plural(r.days, 'day')}'),
        if (r.handover.delivery) item('Delivery', r.deliveryFee > 0 ? money(r.deliveryFee) : 'Free', detail: r.handover.address.isEmpty ? null : 'To ${r.handover.address}'),
        Divider(color: c.line),
        item('Subtotal', money(_subtotal), strong: true),
        if (r.deposit > 0) item('Refundable deposit', money(r.deposit), detail: 'Held with the payment and returned with the tool, minus any late fee'),
        if (r.deposit > 0 || _late > 0) ...[
          Divider(color: c.line),
          item('Charged at booking', money(_subtotal + r.deposit), strong: true),
        ],
        if (_late > 0)
          item(_returned ? 'Late fee' : 'Late fee so far', money(_late),
              detail: '${plural(r.lateDays, 'day')} late × ${money(r.dailyRate)}, kept from the deposit', color: c.danger),
        if (_returned && r.deposit > 0)
          item(p.isWallet ? 'Deposit refunded to wallet' : 'Deposit handed back', '− ${money((r.deposit - _late).clamp(0, r.deposit))}', color: c.success),
        if (_returned || (r.isPurchase && r.status == 'completed')) ...[
          Divider(color: c.line),
          item('Total cost', money(_finalCost), strong: true),
        ],
        if (_closedEarly && p.refunded) item('Refunded in full', '− ${money(_subtotal + r.deposit)}', color: c.success),

        section('Payment'),
        KV('Method', p.isWallet ? 'SureFix Wallet' : 'Cash, paid to the supplier'),
        KV('Status', pay.$1),
        if (p.heldAt != null) KV('Paid into escrow', dateTime(p.heldAt)),
        if (p.settledAt != null) KV(p.refunded ? 'Refunded' : (p.isWallet ? 'Released to the supplier' : 'Settled'), dateTime(p.settledAt)),
        if (forSupplier && p.isWallet && p.fee > 0) ...[
          Divider(color: c.line),
          item('SureFix service fee', '− ${money(p.fee)}', detail: 'On ${money(p.amount)}'),
          if (_late > 0) item('Late fee to you', money(_late)),
          item(p.released ? 'You received' : 'You receive', money(p.net + _late), strong: true, color: c.success),
        ],
        if (r.note.isNotEmpty) ...[section('Note from the customer'), Text(r.note, style: context.text.bodyMedium)],
        Gap.h16,
        Align(
          alignment: Alignment.centerLeft,
          child: Btn('Copy invoice', icon: AppIcons.copy, kind: BtnKind.outline, size: BtnSize.sm, onPressed: () {
            Clipboard.setData(ClipboardData(text: asText()));
            toast('Invoice copied');
          }),
        ),
      ]),
    );
  }
}
