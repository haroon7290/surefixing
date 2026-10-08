import 'package:intl/intl.dart';

/// App-wide formatting. Currency defaults to Pakistani Rupees; override at
/// build time with --dart-define=CURRENCY=$ (or any symbol).
class Fmt {
  static const currency = String.fromEnvironment('CURRENCY', defaultValue: 'Rs');
  static final _num = NumberFormat.decimalPattern();
  static final _compact = NumberFormat.compact();

  static String money(num? v) {
    final n = v ?? 0;
    final s = n == n.roundToDouble() ? _num.format(n.round()) : _num.format(double.parse(n.toStringAsFixed(2)));
    return '$currency $s';
  }

  static String compactMoney(num? v) => '$currency ${_compact.format(v ?? 0)}';

  static String compact(num? v) => _compact.format(v ?? 0);

  static String date(DateTime? d) => d == null ? '' : DateFormat.yMMMd().format(d.toLocal());

  static String shortDate(DateTime? d) => d == null ? '' : DateFormat.MMMd().format(d.toLocal());

  static String time(DateTime? d) => d == null ? '' : DateFormat.jm().format(d.toLocal());

  static String dateTime(DateTime? d) => d == null ? '' : DateFormat('MMM d, h:mm a').format(d.toLocal());

  static String weekday(DateTime? d) => d == null ? '' : DateFormat('EEE, MMM d').format(d.toLocal());

  /// "just now", "5m ago", "3h ago", "Yesterday", "Mar 4".
  static String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(d);
  }

  /// Chat-list style: time today, weekday this week, date otherwise.
  static String chatStamp(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) return time(local);
    if (now.difference(local).inDays < 7) return DateFormat.E().format(local);
    return shortDate(local);
  }

  static String dayLabel(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(local);
  }

  static String responseTime(num minutes) {
    final m = minutes.round();
    if (m < 60) return '~${m < 1 ? 1 : m} min';
    final h = (m / 60).round();
    return '~$h hr';
  }

  static String plural(int n, String word, [String? pluralWord]) => '$n ${n == 1 ? word : (pluralWord ?? '${word}s')}';

  static String titleCase(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}
