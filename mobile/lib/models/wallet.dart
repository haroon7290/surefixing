import 'json.dart';
import 'user.dart';

/// One movement in the wallet ledger. `amount` is signed: + in, − out.
class Txn {
  final String id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String note;
  final String subject; // job title or tool name it relates to
  final User? user; // admin view
  final DateTime? createdAt;
  const Txn({required this.id, this.type = '', this.amount = 0, this.balanceAfter = 0, this.note = '', this.subject = '', this.user, this.createdAt});

  bool get incoming => amount >= 0;

  factory Txn.fromJson(Json j) {
    final job = asJson(j['job']);
    final tool = asJson(asJson(j['rental'])['tool']);
    return Txn(
      id: idOf(j),
      type: str(j['type']),
      amount: dbl(j['amount']),
      balanceAfter: dbl(j['balanceAfter']),
      note: str(j['note']),
      subject: str(job['title'], str(tool['name'])),
      user: j['user'] is Map ? User.fromJson(asJson(j['user'])) : null,
      createdAt: date(j['createdAt']),
    );
  }
}

/// A bank or mobile-wallet account: one of the company's (where deposits
/// are sent) or a user's own (where withdrawals go).
class BankAccount {
  final String id;
  final String kind; // bank | mobile_wallet
  final String provider;
  final String accountTitle;
  final String accountNumber;
  final String iban;
  final String instructions;
  final bool active;
  const BankAccount({this.id = '', this.kind = 'bank', this.provider = '', this.accountTitle = '', this.accountNumber = '', this.iban = '', this.instructions = '', this.active = true});

  bool get isMobileWallet => kind == 'mobile_wallet';
  bool get exists => accountNumber.isNotEmpty;

  /// Company accounts use `kind`, saved payout accounts use `method`.
  factory BankAccount.fromJson(dynamic v) {
    final j = asJson(v);
    return BankAccount(
      id: idOf(j),
      kind: str(j['kind'] ?? j['method'], 'bank'),
      provider: str(j['provider']),
      accountTitle: str(j['accountTitle']),
      accountNumber: str(j['accountNumber']),
      iban: str(j['iban']),
      instructions: str(j['instructions']),
      active: j['active'] != false,
    );
  }

  Json toPayout() => {'method': kind, 'provider': provider, 'accountTitle': accountTitle, 'accountNumber': accountNumber};
  Json toJson() => {'kind': kind, 'provider': provider, 'accountTitle': accountTitle, 'accountNumber': accountNumber, 'iban': iban, 'instructions': instructions, 'active': active};
}

/// A deposit (money sent to a company account) or a withdrawal (money to be
/// sent to the user), waiting for or decided by an admin.
class WalletRequest {
  final String id;
  final String kind; // deposit | withdrawal
  final double amount;
  final String status; // pending | approved | rejected | cancelled
  final BankAccount account; // sent to (deposit) or pay to (withdrawal)
  final String transactionId;
  final String proofImage;
  final String note;
  final String adminNote;
  final String reference;
  final User? user; // admin view
  final String reviewedBy;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const WalletRequest({
    required this.id,
    this.kind = 'deposit',
    this.amount = 0,
    this.status = 'pending',
    this.account = const BankAccount(),
    this.transactionId = '',
    this.proofImage = '',
    this.note = '',
    this.adminNote = '',
    this.reference = '',
    this.user,
    this.reviewedBy = '',
    this.createdAt,
    this.reviewedAt,
  });

  bool get isDeposit => kind == 'deposit';
  bool get pending => status == 'pending';

  factory WalletRequest.fromJson(Json j) => WalletRequest(
        id: idOf(j),
        kind: str(j['kind'], 'deposit'),
        amount: dbl(j['amount']),
        status: str(j['status'], 'pending'),
        account: BankAccount.fromJson(j['kind'] == 'withdrawal' ? j['payout'] : j['sentTo']),
        transactionId: str(j['transactionId']),
        proofImage: str(j['proofImage']),
        note: str(j['note']),
        adminNote: str(j['adminNote']),
        reference: str(j['reference']),
        user: j['user'] is Map ? User.fromJson(asJson(j['user'])) : null,
        reviewedBy: str(asJson(j['reviewedBy'])['name']),
        createdAt: date(j['createdAt']),
        reviewedAt: date(j['reviewedAt']),
      );
}

/// GET /api/wallet.
class WalletSummary {
  final double balance;
  final double held; // paid in by me, waiting in escrow
  final double incoming; // in escrow, to be paid to me
  final double pendingDeposits; // sent to the company, waiting for review
  final double pendingWithdrawals; // asked to be paid out, waiting for review
  final double feePercent;
  final double minDeposit;
  final double maxDeposit;
  final double minWithdrawal;
  final BankAccount payoutAccount;
  final List<Txn> recent;
  const WalletSummary({
    this.balance = 0,
    this.held = 0,
    this.incoming = 0,
    this.pendingDeposits = 0,
    this.pendingWithdrawals = 0,
    this.feePercent = 10,
    this.minDeposit = 100,
    this.maxDeposit = 500000,
    this.minWithdrawal = 500,
    this.payoutAccount = const BankAccount(),
    this.recent = const [],
  });

  factory WalletSummary.fromJson(Json j) => WalletSummary(
        balance: dbl(j['balance']),
        held: dbl(j['held']),
        incoming: dbl(j['incoming']),
        pendingDeposits: dbl(j['pendingDeposits']),
        pendingWithdrawals: dbl(j['pendingWithdrawals']),
        feePercent: dbl(j['feePercent'], 10),
        minDeposit: dbl(j['minDeposit'], 100),
        maxDeposit: dbl(j['maxDeposit'], 500000),
        minWithdrawal: dbl(j['minWithdrawal'], 500),
        payoutAccount: BankAccount.fromJson(j['payoutAccount']),
        recent: asJsonList(j['recent']).map(Txn.fromJson).toList(),
      );
}
