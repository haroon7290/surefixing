import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kit.dart';
import '../wallet/wallet_screen.dart';

/// Money in and out: deposits to check, withdrawals to pay, the ledger, and
/// the company accounts customers send money to.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  String _tab = 'deposit';

  static const _tabs = {'deposit': 'Deposits', 'withdrawal': 'Withdrawals', 'ledger': 'Ledger', 'accounts': 'Company accounts'};

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Payments',
        subtitle: 'Check deposits against your statement, pay out withdrawals, and see every wallet movement.',
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PagePad(child: Pills<String>(scroll: true, values: _tabs.keys.toList(), label: (k) => _tabs[k]!, selected: _tab, onTap: (k) => setState(() => _tab = k))),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                'ledger' => const _Ledger(),
                'accounts' => const _CompanyAccounts(),
                _ => _RequestQueue(kind: _tab),
              },
            ),
          ),
        ]),
      );
}

// ----------------------------------------------------------- the queues

class _RequestQueue extends StatefulWidget {
  final String kind; // deposit | withdrawal
  const _RequestQueue({required this.kind});

  @override
  State<_RequestQueue> createState() => _RequestQueueState();
}

class _RequestQueueState extends State<_RequestQueue> {
  final _view = GlobalKey<AsyncViewState<List<WalletRequest>>>();
  String _status = 'pending';

  bool get _deposits => widget.kind == 'deposit';

  void _reload() => _view.currentState?.reload();

  Future<void> _approve(WalletRequest r) async {
    final amount = TextEditingController(text: '${r.amount.round()}');
    final reference = TextEditingController();
    final form = GlobalKey<FormState>();
    final body = await showAppSheet<Json>(
      context,
      title: _deposits ? 'Approve deposit' : 'Mark withdrawal as sent',
      subtitle: _deposits
          ? 'Check that ${money(r.amount)} with transaction ID ${r.transactionId} arrived in ${r.account.provider}. Approving adds it to ${r.user?.name ?? 'the user'}\'s wallet.'
          : 'Send ${money(r.amount)} to the account below, then confirm here. The money already left their wallet.',
      builder: (context) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_deposits) ...[_AccountBox(r.account), Gap.h16],
          if (_deposits)
            Field(
              label: 'Amount received',
              prefixText: 'Rs  ',
              controller: amount,
              keyboardType: TextInputType.number,
              formatters: Field.digits,
              helper: 'Change it only if a different amount arrived.',
              validator: positiveNumber('Enter the amount'),
            )
          else
            Field(label: 'Your transfer reference', hint: 'e.g. FT-55120931', controller: reference, optional: true, helper: 'Shown to the user so they can find the payment.'),
          Gap.h20,
          Btn(_deposits ? 'Approve and add to wallet' : 'Mark as sent', icon: AppIcons.check, size: BtnSize.lg, expand: true, onPressed: () {
            if (!(form.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_deposits ? {'amount': int.parse(amount.text)} : {'reference': reference.text.trim()});
          }),
        ]),
      ),
    );
    if (body == null) return;
    try {
      await Api.post('/api/admin/wallet-requests/${r.id}/approve', body);
      toastOk(_deposits ? 'Deposit approved — the wallet was credited' : 'Withdrawal marked as sent');
      _reload();
    } catch (e) {
      toastError(e);
      _reload();
    }
  }

  Future<void> _reject(WalletRequest r) async {
    final reason = await promptText(
      context,
      title: _deposits ? 'Reject this deposit?' : 'Reject this withdrawal?',
      message: _deposits ? 'Nothing is added to the wallet. Tell them why.' : '${money(r.amount)} goes back to their wallet. Tell them why.',
      label: 'Reason',
      hint: _deposits ? 'e.g. This transaction ID is not in our statement' : 'e.g. The account title does not match',
      confirmLabel: 'Reject',
      danger: true,
      mandatory: true,
    );
    if (reason == null) return;
    try {
      await Api.post('/api/admin/wallet-requests/${r.id}/reject', {'reason': reason});
      toast('Rejected — the user was told why');
      _reload();
    } catch (e) {
      toastError(e);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(
          child: Pills<String>(
            scroll: true,
            values: const ['pending', 'approved', 'rejected', 'all'],
            label: (k) => const {'pending': 'To review', 'approved': 'Approved', 'rejected': 'Rejected', 'all': 'All'}[k]!,
            selected: _status,
            onTap: (k) => setState(() => _status = k),
          ),
        ),
        Expanded(
          child: AsyncView<List<WalletRequest>>(
            key: _view,
            token: _status,
            load: () async => (await Api.list('/api/admin/wallet-requests', query: {'kind': widget.kind, 'status': _status})).map(WalletRequest.fromJson).toList(),
            events: const {'wallet:request', ...Live.wallet},
            builder: (context, items) => items.isEmpty
                ? EmptyState(
                    icon: _deposits ? AppIcons.topUp : AppIcons.withdraw,
                    title: _status == 'pending' ? 'Nothing to review' : 'None yet',
                    message: _status == 'pending' ? (_deposits ? 'New deposits appear here the moment users submit them.' : 'Withdrawal requests appear here.') : null,
                  )
                : PageList(
                    onRefresh: () => _view.currentState!.reload(),
                    children: [
                      if (_status == 'pending')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${plural(items.length, _deposits ? 'deposit' : 'withdrawal')} · ${money(items.fold<double>(0, (a, r) => a + r.amount))}',
                            style: context.text.bodySmall,
                          ),
                        ),
                      AutoGrid(minWidth: 380, gap: 16, maxColumns: 2, children: [
                        for (final r in items) _RequestCard(r, onApprove: () => _approve(r), onReject: () => _reject(r)),
                      ]),
                    ],
                  ),
          ),
        ),
      ]);
}

class _RequestCard extends StatelessWidget {
  final WalletRequest r;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _RequestCard(this.r, {required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = r.user;
    final status = walletRequestStatus(r.status, deposit: r.isDeposit);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Avatar(name: u?.name ?? '?', image: u?.avatar ?? '', size: 40),
          Gap.w12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(u?.name ?? 'User', style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text([roleLabels[u?.role] ?? '', u?.email ?? ''].where((x) => x.isNotEmpty).join('  ·  '), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(money(r.amount), style: context.text.titleLarge),
            Text(timeAgo(r.createdAt), style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
          ]),
        ]),
        Gap.h12,
        if (r.isDeposit) ...[
          _CopyRow('Transaction ID', r.transactionId, strong: true),
          _InfoRow('Sent to', '${r.account.provider} · ${r.account.accountNumber}'),
          if (r.proofImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                button: true,
                label: 'View the transfer screenshot',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => openGallery(context, [r.proofImage]),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(R.sm), child: NetImage(r.proofImage, width: 56, height: 56)),
                    Gap.w12,
                    Text('Screenshot attached — tap to view', style: context.text.bodySmall!.copyWith(color: c.ink, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
        ] else
          _AccountBox(r.account),
        if (r.note.isNotEmpty) ...[Gap.h8, Text('"${r.note}"', style: context.text.bodyMedium!.copyWith(fontSize: 13.5))],
        if (!r.isDeposit && u != null && r.pending) ...[Gap.h8, Text('Wallet balance now: ${money(u.walletBalance)} (this amount is already set aside)', style: context.text.bodySmall)],
        Gap.h12,
        if (r.pending)
          Row(children: [
            Expanded(child: Btn('Reject', kind: BtnKind.outline, expand: true, onPressed: onReject)),
            Gap.w8,
            Expanded(child: Btn(r.isDeposit ? 'Approve' : 'Mark as sent', icon: AppIcons.check, expand: true, onPressed: onApprove)),
          ])
        else
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Pill.status(status),
            if (r.reviewedBy.isNotEmpty) Text('by ${r.reviewedBy} · ${timeAgo(r.reviewedAt)}', style: context.text.bodySmall),
            if (r.reference.isNotEmpty) Text('Ref ${r.reference}', style: context.text.bodySmall),
            if (r.adminNote.isNotEmpty) Text(r.adminNote, style: context.text.bodySmall!.copyWith(color: r.status == 'rejected' ? c.danger : c.body)),
          ]),
      ]),
    );
  }
}

/// Where to send a payout, with copy buttons.
class _AccountBox extends StatelessWidget {
  final BankAccount account;
  const _AccountBox(this.account);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(account.isMobileWallet ? AppIcons.mobile : AppIcons.bank, size: 16, color: c.body),
          Gap.w8,
          Text('Pay to · ${account.provider}', style: context.text.titleSmall),
        ]),
        Gap.h6,
        _CopyRow('Title', account.accountTitle),
        _CopyRow(account.isMobileWallet ? 'Number' : 'Account', account.accountNumber, strong: true),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 108, child: Text(label, style: context.text.bodySmall)),
          Expanded(child: Text(value, style: context.text.titleSmall!.copyWith(fontSize: 13.5))),
        ]),
      );
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _CopyRow(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) => Semantics(
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
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 108, child: Text(label, style: context.text.bodySmall)),
              Expanded(child: Text(value, style: (strong ? context.text.titleMedium : context.text.titleSmall)!.copyWith(fontSize: strong ? 15 : 13.5, letterSpacing: 0.2))),
              Icon(AppIcons.copy, size: 14, color: context.colors.muted),
            ]),
          ),
        ),
      );
}

// --------------------------------------------------------------- ledger

class _Ledger extends StatefulWidget {
  const _Ledger();

  @override
  State<_Ledger> createState() => _LedgerState();
}

class _LedgerState extends State<_Ledger> {
  String _type = 'all';

  static const _types = {
    'all': 'Everything',
    'deposit': 'Deposits',
    'withdrawal': 'Withdrawals',
    'platform_fee': 'Fees earned',
    'job_hold': 'Into escrow',
    'job_earning': 'Paid to technicians',
    'job_refund': 'Refunds',
    'rental_earning': 'Rental income',
  };

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PagePad(child: Pills<String>(scroll: true, values: _types.keys.toList(), label: (k) => _types[k]!, selected: _type, onTap: (k) => setState(() => _type = k))),
        Expanded(
          child: AsyncView<List<Txn>>(
            token: _type,
            load: () async => (await Api.list('/api/admin/transactions', query: {'type': _type == 'all' ? null : _type, 'limit': 150})).map(Txn.fromJson).toList(),
            events: Live.wallet,
            builder: (context, items) => items.isEmpty
                ? const EmptyState(icon: AppIcons.payments, title: 'No transactions yet')
                : PageList(maxWidth: 900, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${plural(items.length, 'movement')}  ·  net ${signedMoney(items.fold<double>(0, (a, t) => a + t.amount))}', style: context.text.bodySmall),
                    ),
                    TxnList(items, showUser: true),
                  ]),
          ),
        ),
      ]);
}

// ----------------------------------------------------- company accounts

class _CompanyAccounts extends StatefulWidget {
  const _CompanyAccounts();

  @override
  State<_CompanyAccounts> createState() => _CompanyAccountsState();
}

class _CompanyAccountsState extends State<_CompanyAccounts> {
  final _view = GlobalKey<AsyncViewState<List<BankAccount>>>();

  Future<void> _edit([BankAccount? account]) async {
    final saved = await showAccountForm(context, account);
    if (saved) _view.currentState?.reload();
  }

  Future<void> _toggle(BankAccount a, bool active) async {
    try {
      await Api.patch('/api/admin/payment-accounts/${a.id}', {'active': active});
      toast(active ? '${a.provider} is shown to users again' : '${a.provider} is hidden from users', kind: ToastKind.success);
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) => AsyncView<List<BankAccount>>(
        key: _view,
        load: () async => (await Api.list('/api/admin/payment-accounts')).map(BankAccount.fromJson).toList(),
        builder: (context, accounts) => PageList(maxWidth: 900, children: [
          const Notice(
            'Users see the accounts switched on here when they add money. They send the money, then enter the amount and transaction ID for you to check.',
            tone: Tone.info,
          ),
          Gap.h16,
          for (final a in accounts) ...[
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: a.active ? 1 : 0.5, child: CompanyAccountCard(a)),
                Gap.h8,
                Row(children: [
                  Text(a.active ? 'Shown to users' : 'Hidden', style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w700)),
                  Switch(value: a.active, onChanged: (v) => _toggle(a, v)),
                  const Spacer(),
                  Btn('Edit', icon: AppIcons.edit, kind: BtnKind.soft, size: BtnSize.sm, onPressed: () => _edit(a)),
                ]),
              ]),
            ),
            Gap.h12,
          ],
          if (accounts.isEmpty) const Panel(child: EmptyState(compact: true, icon: AppIcons.bank, title: 'No accounts yet', message: 'Add the bank or wallet account users should send money to.')),
          Gap.h12,
          Btn('Add an account', icon: AppIcons.add, expand: true, onPressed: () => _edit()),
        ]),
      );
}

/// Add or edit a company account. Returns true when saved.
Future<bool> showAccountForm(BuildContext context, BankAccount? account) async {
  final form = GlobalKey<FormState>();
  final provider = TextEditingController(text: account?.provider ?? '');
  final title = TextEditingController(text: account?.accountTitle ?? '');
  final number = TextEditingController(text: account?.accountNumber ?? '');
  final iban = TextEditingController(text: account?.iban ?? '');
  final instructions = TextEditingController(text: account?.instructions ?? '');
  var kind = account?.kind ?? 'bank';
  var busy = false;
  final saved = await showAppSheet<bool>(
    context,
    title: account == null ? 'Add a company account' : 'Edit account',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Segmented<String>(options: payoutMethods, icons: const {'bank': AppIcons.bank, 'mobile_wallet': AppIcons.mobile}, value: kind, onChanged: (v) => setState(() => kind = v)),
          Gap.h16,
          Field(label: kind == 'bank' ? 'Bank' : 'Wallet', hint: kind == 'bank' ? 'Meezan Bank' : 'JazzCash', controller: provider, validator: minLength(2, 'Enter the name')),
          Gap.h16,
          Field(label: 'Account title', hint: 'SureFix Services', controller: title, validator: minLength(2, 'Enter the account title')),
          Gap.h16,
          Field(label: kind == 'bank' ? 'Account number' : 'Mobile number', controller: number, validator: minLength(4, 'Enter the number')),
          if (kind == 'bank') ...[Gap.h16, Field(label: 'IBAN', controller: iban, optional: true)],
          Gap.h16,
          Field(label: 'Instructions for users', hint: 'e.g. Use your name as the reference', controller: instructions, optional: true, maxLength: 300),
          Gap.h12,
          Btn('Save', size: BtnSize.lg, expand: true, loading: busy, onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            final body = {
              'kind': kind,
              'provider': provider.text.trim(),
              'accountTitle': title.text.trim(),
              'accountNumber': number.text.trim(),
              'iban': kind == 'bank' ? iban.text.trim() : '',
              'instructions': instructions.text.trim(),
            };
            try {
              account == null ? await Api.post('/api/admin/payment-accounts', body) : await Api.patch('/api/admin/payment-accounts/${account.id}', body);
              toastOk('Saved');
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
  return saved ?? false;
}
