import 'package:flutter/material.dart';

import '../../kit.dart';

/// The sandbox wallet: balance, money in escrow, top-ups, payouts and the
/// ledger of every movement.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _view = GlobalKey<AsyncViewState<WalletSummary>>();

  Future<WalletSummary> _load() async => WalletSummary.fromJson(await Api.map('/api/wallet'));

  Future<void> _changed() async {
    await Session.instance.refresh();
    await _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final role = Session.instance.role;
    return AppPage(
      title: 'Wallet',
      subtitle: 'Pay safely through escrow and keep track of every rupee.',
      body: AsyncView<WalletSummary>(
        key: _view,
        load: _load,
        events: Live.wallet,
        builder: (context, w) {
          final balance = HeroCard(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text('AVAILABLE BALANCE', style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.onHeroMuted)),
                const Spacer(),
                const Pill('Sandbox', solid: true),
              ]),
              Gap.h8,
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money(w.balance), style: context.text.displayMedium!.copyWith(color: c.onHero))),
              Gap.h20,
              Row(children: [
                Expanded(
                  child: Btn('Add funds', icon: AppIcons.topUp, expand: true, onPressed: () async {
                    if (await showTopUp(context, max: w.maxTopUp)) _changed();
                  }),
                ),
                Gap.w12,
                Expanded(
                  child: Btn('Withdraw',
                      icon: AppIcons.withdraw,
                      kind: BtnKind.soft,
                      expand: true,
                      onPressed: w.balance < 100
                          ? null
                          : () async {
                              if (await _showWithdraw(context, w.balance)) _changed();
                            }),
                ),
              ]),
            ]),
          );

          final escrow = Row(children: [
            Expanded(
              child: StatCard(
                label: role == 'client' ? 'Held in escrow' : 'You paid, in escrow',
                value: moneyCompact(w.held),
                icon: AppIcons.lock,
                tone: Tone.info,
                caption: 'Released when you confirm',
              ),
            ),
            Gap.w12,
            Expanded(
              child: StatCard(
                label: 'On its way to you',
                value: moneyCompact(w.incoming),
                icon: AppIcons.hourglass,
                tone: Tone.success,
                caption: 'Paid out on completion',
              ),
            ),
          ]);

          final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Notice(
              'This is a project build: top-ups add demo funds and withdrawals just lower the balance. No real money moves.',
              title: 'Sandbox wallet',
              tone: Tone.brand,
            ),
            Gap.h12,
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('How escrow protects you', style: context.text.titleMedium),
                Gap.h12,
                for (final (icon, text) in [
                  (AppIcons.lock, 'When you hire or rent with the wallet, the money is held by SureFix, not paid out.'),
                  (AppIcons.check, 'It is released when the job is confirmed or the tool is returned.'),
                  (AppIcons.refresh, 'Cancelled or declined? It goes straight back to your wallet.'),
                  (AppIcons.payments, 'SureFix keeps a ${w.feePercent.round()}% service fee from released payments.'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(icon, size: 17, color: c.brandDeep),
                      Gap.w12,
                      Expanded(child: Text(text, style: context.text.bodyMedium!.copyWith(fontSize: 13.5))),
                    ]),
                  ),
              ]),
            ),
          ]);

          return PageList(
            onRefresh: () => _view.currentState!.reload(),
            children: [
              TwoCol(
                main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  balance,
                  Gap.h12,
                  escrow,
                  SectionTitle('Recent activity', action: w.recent.length >= 10 ? 'See all' : null, onAction: () => push(context, const TransactionsScreen())),
                  if (w.recent.isEmpty)
                    const Panel(child: EmptyState(compact: true, icon: AppIcons.payments, title: 'No activity yet', message: 'Add funds to pay for jobs and rentals through escrow.'))
                  else
                    TxnList(w.recent),
                ]),
                side: info,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ledger rows in one card.
class TxnList extends StatelessWidget {
  final List<Txn> items;
  final bool showUser;
  const TxnList(this.items, {super.key, this.showUser = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(indent: 68, color: c.line),
          Builder(builder: (context) {
            final t = items[i];
            final (title, icon) = txnInfo(t.type);
            final who = showUser ? (t.user?.name ?? 'SureFix') : null;
            final detail = [if (who != null) who, if (t.subject.isNotEmpty) t.subject else if (t.note.isNotEmpty && !showUser) t.note, dateTime(t.createdAt)].join('  ·  ');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                IconTile(icon, tone: t.incoming ? Tone.success : Tone.neutral, size: 40, round: true),
                Gap.w12,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(detail, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                Gap.w8,
                Text(signedMoney(t.amount), style: context.text.titleSmall!.copyWith(color: t.incoming ? c.success : c.ink)),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

/// Full transaction history.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Transactions',
        maxWidth: 820,
        body: AsyncView<List<Txn>>(
          load: () async => (await Api.list('/api/wallet/transactions', query: {'limit': 100})).map(Txn.fromJson).toList(),
          events: Live.wallet,
          builder: (context, items) => items.isEmpty ? const EmptyState(icon: AppIcons.payments, title: 'No transactions yet') : PageList(children: [TxnList(items)]),
        ),
      );
}

const _quickAmounts = [1000, 2500, 5000, 10000];

/// Adds demo funds. Returns true when the balance changed.
Future<bool> showTopUp(BuildContext context, {double max = 100000, double? suggested}) async {
  final amount = TextEditingController(text: suggested == null ? '' : '${suggested.ceil()}');
  final form = GlobalKey<FormState>();
  var method = 'card';
  var busy = false;
  final done = await showAppSheet<bool>(
    context,
    title: 'Add funds',
    subtitle: 'Demo top-up — no real payment is taken.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(
            label: 'Amount',
            hint: '5000',
            prefixText: 'Rs  ',
            controller: amount,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            autofocus: suggested == null,
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              if (n < 100) return 'Enter at least Rs 100';
              if (n > max) return 'You can add up to ${money(max)} at a time';
              return null;
            },
          ),
          Gap.h12,
          Pills<int>(values: _quickAmounts, label: (v) => money(v), selected: int.tryParse(amount.text), onTap: (v) => setState(() => amount.text = '$v')),
          Gap.h20,
          const FieldLabel('Pay with'),
          Segmented<String>(
            options: const {'card': 'Bank card', 'mobile': 'Mobile wallet', 'bank': 'Bank transfer'},
            value: method,
            onChanged: (v) => setState(() => method = v),
          ),
          Gap.h20,
          Btn('Add funds', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            try {
              await Api.post('/api/wallet/topup', {'amount': int.parse(amount.text)});
              await Session.instance.refresh();
              toastOk('${money(int.parse(amount.text))} added to your wallet');
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              toastError(e);
              if (context.mounted) setState(() => busy = false);
            }
          }),
        ]),
      ),
    ),
  );
  return done ?? false;
}

Future<bool> _showWithdraw(BuildContext context, double balance) async {
  final amount = TextEditingController();
  final form = GlobalKey<FormState>();
  var busy = false;
  final done = await showAppSheet<bool>(
    context,
    title: 'Withdraw',
    subtitle: 'Demo payout to your bank. Available: ${money(balance)}.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(
            label: 'Amount',
            hint: '${balance.floor()}',
            prefixText: 'Rs  ',
            controller: amount,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            autofocus: true,
            suffix: TextButton(onPressed: () => setState(() => amount.text = '${balance.floor()}'), child: const Text('Max')),
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              if (n < 100) return 'Enter at least Rs 100';
              if (n > balance) return 'You only have ${money(balance)}';
              return null;
            },
          ),
          Gap.h20,
          Btn('Withdraw', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            try {
              await Api.post('/api/wallet/withdraw', {'amount': int.parse(amount.text)});
              await Session.instance.refresh();
              toastOk('${money(int.parse(amount.text))} is on its way to your bank');
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              toastError(e);
              if (context.mounted) setState(() => busy = false);
            }
          }),
        ]),
      ),
    ),
  );
  return done ?? false;
}

/// Asks how to pay for a job or rental. Returns `wallet`, `cash` or null
/// (cancelled). When the wallet is short the sheet offers to top up the
/// difference first.
Future<String?> choosePayment(
  BuildContext context, {
  required String title,
  required double amount,
  double deposit = 0,
  required String walletNote,
  required String cashNote,
  String confirmLabel = 'Confirm',
}) {
  var method = 'wallet';
  final total = amount + deposit;
  return showAppSheet<String>(
    context,
    title: title,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => ListenableBuilder(
        listenable: Session.instance,
        builder: (context, _) {
          final c = context.colors;
          final balance = Session.instance.user?.walletBalance ?? 0;
          final short = total - balance;

          Widget option(String key, IconData icon, String label, String detail, {Widget? badge}) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  button: true,
                  selected: method == key,
                  child: Panel(
                    onTap: () => setState(() => method = key),
                    border: method == key ? c.ink : null,
                    borderWidth: method == key ? 1.6 : 1,
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      IconTile(icon, tone: method == key ? Tone.brand : Tone.neutral),
                      Gap.w12,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            Flexible(child: Text(label, style: context.text.titleSmall!.copyWith(fontSize: 15))),
                            if (badge != null) ...[Gap.w8, badge]
                          ]),
                          Gap.h2,
                          Text(detail, style: context.text.bodySmall),
                        ]),
                      ),
                      Icon(method == key ? AppIcons.success : AppIcons.circle, size: 22, color: method == key ? c.brand : c.line),
                    ]),
                  ),
                ),
              );

          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                KV(deposit > 0 ? 'Rental cost' : 'Price', money(amount)),
                if (deposit > 0) KV('Refundable deposit', money(deposit)),
                if (deposit > 0) ...[const Divider(), KV('Total', money(total), strong: true)],
              ]),
            ),
            Gap.h16,
            option('wallet', AppIcons.shield, 'SureFix Wallet', 'Balance ${money(balance)}', badge: const Pill('Protected', tone: Tone.success)),
            option('cash', AppIcons.cash, 'Cash', 'Pay in person'),
            Text(method == 'wallet' ? walletNote : cashNote, style: context.text.bodyMedium!.copyWith(fontSize: 13.5)),
            if (method == 'wallet' && short > 0) ...[
              Gap.h12,
              Notice(
                'You need ${money(short)} more in your wallet.',
                tone: Tone.warning,
                action: Btn('Add ${money(short < 100 ? 100 : short)}', kind: BtnKind.dark, size: BtnSize.sm, onPressed: () => showTopUp(context, suggested: short < 100 ? 100 : short)),
              ),
            ],
            Gap.h20,
            Btn(
              method == 'wallet' ? '$confirmLabel · ${money(total)}' : confirmLabel,
              size: BtnSize.lg,
              expand: true,
              onPressed: method == 'wallet' && short > 0 ? null : () => Navigator.of(context).pop(method),
            ),
          ]);
        },
      ),
    ),
  );
}
