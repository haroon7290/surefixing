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

/// GET /api/wallet.
class WalletSummary {
  final double balance;
  final double held; // paid in by me, waiting in escrow
  final double incoming; // in escrow, to be paid to me
  final double feePercent;
  final double maxTopUp;
  final List<Txn> recent;
  const WalletSummary({this.balance = 0, this.held = 0, this.incoming = 0, this.feePercent = 10, this.maxTopUp = 100000, this.recent = const []});

  factory WalletSummary.fromJson(Json j) => WalletSummary(
        balance: dbl(j['balance']),
        held: dbl(j['held']),
        incoming: dbl(j['incoming']),
        feePercent: dbl(j['feePercent'], 10),
        maxTopUp: dbl(j['maxTopUp'], 100000),
        recent: asJsonList(j['recent']).map(Txn.fromJson).toList(),
      );
}
