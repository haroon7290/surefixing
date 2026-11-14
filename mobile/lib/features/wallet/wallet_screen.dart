import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';

/// The wallet: balance, money in escrow, deposits and withdrawals through
/// the company's accounts (each checked by an admin), and the ledger.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletData {
  final WalletSummary summary;
  final List<WalletRequest> requests;
  const _WalletData(this.summary, this.requests);
}

class _WalletScreenState extends State<WalletScreen> {
  final _view = GlobalKey<AsyncViewState<_WalletData>>();

  Future<_WalletData> _load() async {
    final results = await Future.wait([Api.map('/api/wallet'), Api.list('/api/wallet/requests', query: {'limit': 20})]);
    return _WalletData(WalletSummary.fromJson(results[0] as Json), (results[1] as List<Json>).map(WalletRequest.fromJson).toList());
  }

  Future<void> _changed() async {
    await Session.instance.refresh();
    await _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'Wallet',
      subtitle: 'Pay safely through escrow and keep track of every rupee.',
      body: AsyncView<_WalletData>(
        key: _view,
        load: _load,
        events: const {...Live.wallet, ...Live.notifications},
        builder: (context, data) {
          final w = data.summary;
          final waiting = data.requests.where((r) => r.pending).toList();
          final balance = HeroCard(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('AVAILABLE BALANCE', style: TextStyle(fontFamily: kBodyFont, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.onHeroMuted)),
              Gap.h8,
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money(w.balance), style: context.text.displayMedium!.copyWith(color: c.onHero))),
              if (w.pendingDeposits > 0 || w.pendingWithdrawals > 0) ...[
                Gap.h4,
                Text(
                  [
                    if (w.pendingDeposits > 0) '${money(w.pendingDeposits)} being checked',
                    if (w.pendingWithdrawals > 0) '${money(w.pendingWithdrawals)} on its way to your account',
                  ].join('  ·  '),
                  style: context.text.bodySmall!.copyWith(color: c.onHeroMuted),
                ),
              ],
              Gap.h20,
              Row(children: [
                Expanded(
                  child: Btn('Add money', icon: AppIcons.topUp, expand: true, onPressed: () async {
                    if (await showDeposit(context, summary: w)) _changed();
                  }),
                ),
                Gap.w12,
                Expanded(
                  child: Btn('Withdraw', icon: AppIcons.withdraw, kind: BtnKind.soft, expand: true, onPressed: () async {
                    if (await showWithdraw(context, w)) _changed();
                  }),
                ),
              ]),
            ]),
          );

          final escrow = Row(children: [
            Expanded(child: StatCard(label: 'Held in escrow', value: moneyCompact(w.held), icon: AppIcons.lock, tone: Tone.info, caption: 'Released when you confirm')),
            Gap.w12,
            Expanded(child: StatCard(label: 'On its way to you', value: moneyCompact(w.incoming), icon: AppIcons.hourglass, tone: Tone.success, caption: 'Paid out on completion')),
          ]);

          final info = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('How it works', style: context.text.titleMedium),
                Gap.h12,
                for (final (icon, text) in [
                  (AppIcons.bank, 'Add money: send it to one of our accounts, then enter the amount and the transaction ID. Our team checks it and adds it to your wallet.'),
                  (AppIcons.withdraw, 'Withdraw: enter your bank or mobile wallet account. The amount is set aside at once and sent to you after a quick check.'),
                  (AppIcons.lock, 'When you hire or rent with the wallet, the money is held by SureFix and released only when the job is confirmed or the tool returned.'),
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
                  if (data.requests.isNotEmpty) ...[
                    SectionTitle(waiting.isEmpty ? 'Deposits & withdrawals' : 'Waiting for review (${waiting.length})', action: data.requests.length > 5 ? 'See all' : null, onAction: () => push(context, const WalletRequestsScreen())),
                    RequestList(data.requests.take(5).toList(), onChanged: _changed),
                  ],
                  SectionTitle('Recent activity', action: w.recent.length >= 10 ? 'See all' : null, onAction: () => push(context, const TransactionsScreen())),
                  if (w.recent.isEmpty)
                    const Panel(child: EmptyState(compact: true, icon: AppIcons.payments, title: 'No activity yet', message: 'Add money to pay for jobs and rentals through escrow.'))
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

/// Deposits and withdrawals in one card, with their status.
class RequestList extends StatelessWidget {
  final List<WalletRequest> items;
  final VoidCallback? onChanged;
  const RequestList(this.items, {super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(indent: 68, color: c.line),
          _RequestRow(items[i], onChanged: onChanged),
        ],
      ]),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final WalletRequest r;
  final VoidCallback? onChanged;
  const _RequestRow(this.r, {this.onChanged});

  Future<void> _cancel(BuildContext context) async {
    final ok = await confirm(
      context,
      title: r.isDeposit ? 'Cancel this deposit?' : 'Cancel this withdrawal?',
      message: r.isDeposit ? 'Only do this if you entered something wrong. You can submit it again.' : '${money(r.amount)} goes back to your wallet.',
      confirmLabel: 'Cancel it',
      cancelLabel: 'Keep it',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.post('/api/wallet/requests/${r.id}/cancel');
      toast('Cancelled');
      onChanged?.call();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = walletRequestStatus(r.status, deposit: r.isDeposit);
    final where = r.account.exists ? '${r.account.provider} · ${r.account.accountNumber}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconTile(r.isDeposit ? AppIcons.topUp : AppIcons.withdraw, tone: status.$2 == Tone.neutral ? Tone.neutral : status.$2, size: 40, round: true),
        Gap.w12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(r.isDeposit ? 'Add money' : 'Withdrawal', style: context.text.titleSmall)),
              Text(money(r.amount), style: context.text.titleSmall!.copyWith(color: r.status == 'approved' && r.isDeposit ? c.success : c.ink)),
            ]),
            Gap.h2,
            Text(
              [if (where.isNotEmpty) (r.isDeposit ? 'to $where' : 'to $where'), if (r.transactionId.isNotEmpty) 'TX ${r.transactionId}', timeAgo(r.createdAt)].join('  ·  '),
              style: context.text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Gap.h6,
            Row(children: [
              Pill.status(status),
              const Spacer(),
              if (r.pending) LinkText('Cancel', onTap: () => _cancel(context), color: c.danger),
            ]),
            if (r.status == 'rejected' && r.adminNote.isNotEmpty) ...[Gap.h6, Text(r.adminNote, style: context.text.bodySmall!.copyWith(color: c.danger))],
            if (r.status == 'approved' && r.reference.isNotEmpty) ...[Gap.h6, Text('Reference: ${r.reference}', style: context.text.bodySmall)],
          ]),
        ),
      ]),
    );
  }
}

/// All of the user's deposits and withdrawals.
class WalletRequestsScreen extends StatefulWidget {
  const WalletRequestsScreen({super.key});

  @override
  State<WalletRequestsScreen> createState() => _WalletRequestsScreenState();
}

class _WalletRequestsScreenState extends State<WalletRequestsScreen> {
  final _view = GlobalKey<AsyncViewState<List<WalletRequest>>>();

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Deposits & withdrawals',
        maxWidth: 820,
        body: AsyncView<List<WalletRequest>>(
          key: _view,
          load: () async => (await Api.list('/api/wallet/requests', query: {'limit': 100})).map(WalletRequest.fromJson).toList(),
          events: const {...Live.wallet, ...Live.notifications},
          builder: (context, items) => items.isEmpty
              ? const EmptyState(icon: AppIcons.bank, title: 'Nothing yet')
              : PageList(children: [RequestList(items, onChanged: () => _view.currentState?.reload())]),
        ),
      );
}

/// A company account with copy buttons for the number and IBAN.
class CompanyAccountCard extends StatelessWidget {
  final BankAccount account;
  final bool selected;
  final VoidCallback? onTap;
  const CompanyAccountCard(this.account, {super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget copyLine(String label, String value) => Semantics(
          button: true,
          label: 'Copy $label $value',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(R.sm),
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              toast('$label copied');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 74, child: Text(label, style: context.text.bodySmall)),
                Expanded(child: Text(value, style: context.text.titleSmall!.copyWith(letterSpacing: 0.3))),
                Icon(AppIcons.copy, size: 15, color: c.muted),
              ]),
            ),
          ),
        );
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Panel(
        onTap: onTap,
        border: selected ? c.ink : null,
        borderWidth: selected ? 1.6 : 1,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconTile(account.isMobileWallet ? AppIcons.mobile : AppIcons.bank, tone: selected ? Tone.brand : Tone.neutral, size: 38),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(account.provider, style: context.text.titleSmall!.copyWith(fontSize: 15)),
                Text(account.accountTitle, style: context.text.bodySmall),
              ]),
            ),
            if (onTap != null) Icon(selected ? AppIcons.success : AppIcons.circle, size: 22, color: selected ? c.brand : c.line),
          ]),
          Gap.h8,
          copyLine(account.isMobileWallet ? 'Number' : 'Account', account.accountNumber),
          if (account.iban.isNotEmpty) copyLine('IBAN', account.iban),
          if (account.instructions.isNotEmpty) ...[Gap.h4, Text(account.instructions, style: context.text.bodySmall)],
        ]),
      ),
    );
  }
}

/// "I sent money to your account": pick the account, enter the amount and
/// the transaction ID, optionally attach the receipt. Returns true when sent.
Future<bool> showDeposit(BuildContext context, {WalletSummary? summary, double? suggested}) async {
  List<BankAccount> accounts;
  try {
    accounts = (await Api.list('/api/wallet/accounts')).map(BankAccount.fromJson).toList();
  } catch (e) {
    toastError(e);
    return false;
  }
  if (!context.mounted) return false;
  if (accounts.isEmpty) {
    toast('No company account is set up yet. Please try again later.', kind: ToastKind.error);
    return false;
  }
  final min = summary?.minDeposit ?? 100;
  final max = summary?.maxDeposit ?? 500000;
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(text: suggested == null ? '' : '${(suggested < min ? min : suggested).ceil()}');
  final txId = TextEditingController();
  var account = accounts.first;
  XFile? proof;
  var busy = false;

  final done = await showAppSheet<bool>(
    context,
    title: 'Add money',
    subtitle: '1. Send the money to one of these accounts.  2. Enter the amount and the transaction ID.  3. We check it and add it to your wallet.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const FieldLabel('Send to'),
          for (final a in accounts) ...[
            CompanyAccountCard(a, selected: a.id == account.id, onTap: accounts.length > 1 ? () => setState(() => account = a) : null),
            Gap.h8,
          ],
          Gap.h8,
          Field(
            label: 'Amount you sent',
            hint: '5000',
            prefixText: 'Rs  ',
            controller: amount,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              if (n < min) return 'Enter at least ${money(min)}';
              if (n > max) return 'You can add up to ${money(max)} at a time';
              return null;
            },
          ),
          Gap.h16,
          Field(
            label: 'Transaction ID',
            hint: 'From your bank or wallet app, e.g. 4829 1734 55',
            controller: txId,
            icon: AppIcons.payments,
            maxLength: 64,
            helper: 'Find it in the confirmation message or the app\'s transaction history.',
            validator: (v) => (v ?? '').trim().length < 4 ? 'Enter the transaction ID' : null,
          ),
          Gap.h16,
          const FieldLabel('Screenshot of the transfer', optional: true),
          Row(children: [
            if (proof != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(R.sm), child: LocalImage(proof!, size: 64)),
              Gap.w12,
            ],
            Btn(proof == null ? 'Attach screenshot' : 'Change', icon: AppIcons.image, kind: BtnKind.soft, size: BtnSize.sm, onPressed: () async {
              final file = await pickPhoto(context);
              if (file != null) setState(() => proof = file);
            }),
          ]),
          Gap.h20,
          Btn('Submit for review', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            try {
              await Api.upload('/api/wallet/deposits', fields: {
                'accountId': account.id,
                'amount': amount.text,
                'transactionId': txId.text.trim(),
              }, files: {
                if (proof != null) 'proof': [proof!],
              });
              toastOk('Sent for review. We will add it to your wallet once it is checked.');
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

/// "Send my money to this account". The amount leaves the wallet at once
/// and is sent after a check. Returns true when requested.
Future<bool> showWithdraw(BuildContext context, WalletSummary w) async {
  final saved = w.payoutAccount;
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final provider = TextEditingController(text: saved.provider);
  final title = TextEditingController(text: saved.accountTitle.isEmpty ? (Session.instance.user?.name ?? '') : saved.accountTitle);
  final number = TextEditingController(text: saved.accountNumber);
  var method = saved.exists ? saved.kind : 'bank';
  var busy = false;

  if (w.balance < w.minWithdrawal) {
    toast('You can withdraw once you have at least ${money(w.minWithdrawal)} in your wallet.');
    return false;
  }

  final done = await showAppSheet<bool>(
    context,
    title: 'Withdraw',
    subtitle: 'Available: ${money(w.balance)}. The amount is set aside now and sent to your account after a quick check.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field(
            label: 'Amount',
            hint: '${w.balance.floor()}',
            prefixText: 'Rs  ',
            controller: amount,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            suffix: TextButton(onPressed: () => setState(() => amount.text = '${w.balance.floor()}'), child: const Text('All')),
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              if (n < w.minWithdrawal) return 'You can withdraw ${money(w.minWithdrawal)} or more';
              if (n > w.balance) return 'You only have ${money(w.balance)}';
              return null;
            },
          ),
          Gap.h20,
          const FieldLabel('Send it to'),
          Segmented<String>(
            options: payoutMethods,
            icons: const {'bank': AppIcons.bank, 'mobile_wallet': AppIcons.mobile},
            value: method,
            onChanged: (v) => setState(() => method = v),
          ),
          Gap.h16,
          Field(
            label: method == 'bank' ? 'Bank' : 'Wallet',
            hint: method == 'bank' ? 'e.g. HBL, Meezan Bank' : 'e.g. JazzCash, Easypaisa',
            controller: provider,
            capitalization: TextCapitalization.words,
            validator: minLength(2, method == 'bank' ? 'Enter your bank' : 'Enter your wallet'),
          ),
          Gap.h16,
          Field(label: 'Account title', hint: 'Name on the account', controller: title, capitalization: TextCapitalization.words, validator: minLength(2, 'Enter the account title')),
          Gap.h16,
          Field(
            label: method == 'bank' ? 'Account number or IBAN' : 'Mobile number',
            hint: method == 'bank' ? 'PK36 MEZN 0001 0101 0456 7890' : '0300-1234567',
            controller: number,
            keyboardType: method == 'bank' ? TextInputType.text : TextInputType.phone,
            validator: minLength(4, 'Enter the account number'),
          ),
          Gap.h8,
          Text('Saved for next time.', style: context.text.bodySmall),
          Gap.h20,
          Btn('Request withdrawal', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            try {
              await Api.post('/api/wallet/withdrawals', {
                'amount': int.parse(amount.text),
                'method': method,
                'provider': provider.text.trim(),
                'accountTitle': title.text.trim(),
                'accountNumber': number.text.trim(),
              });
              await Session.instance.refresh();
              toastOk('Withdrawal requested. ${money(int.parse(amount.text))} will be sent to your account.');
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
                'You need ${money(short)} more in your wallet. Send it to a SureFix account and add the transaction ID — it is added once our team checks it. Or choose cash.',
                tone: Tone.warning,
                action: Btn('Add money', kind: BtnKind.dark, size: BtnSize.sm, onPressed: () => showDeposit(context, suggested: short)),
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
