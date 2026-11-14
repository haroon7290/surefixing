import 'package:intl/intl.dart';

/// Text formatting shared by every screen: money, dates and labels.

final _whole = NumberFormat('#,##0');
final _compact = NumberFormat.compact();

/// "Rs 2,500". Amounts are whole rupees in the UI.
String money(num? amount) => 'Rs ${_whole.format((amount ?? 0).round())}';

/// "Rs 12.5K" for tight spaces (stat tiles, charts).
String moneyCompact(num? amount) {
  final v = (amount ?? 0).round();
  return v.abs() < 10000 ? money(v) : 'Rs ${_compact.format(v)}';
}

/// "+Rs 500" / "−Rs 500" for ledger rows.
String signedMoney(num amount) => '${amount < 0 ? '−' : '+'}${money(amount.abs())}';

String count(num n) => _whole.format(n);

String plural(num n, String one, [String? many]) => '${count(n)} ${n == 1 ? one : (many ?? '${one}s')}';

/// "plumbing" → "Plumbing", "on_the_way" → "On the way".
String humanize(String key) {
  final s = key.replaceAll('_', ' ').trim();
  return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// "just now", "5 min ago", "3 h ago", "yesterday", "12 Nov".
String timeAgo(DateTime? at) {
  if (at == null) return '';
  final d = DateTime.now().difference(at);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return shortDate(at);
}

/// "12 Nov" (adds the year when it is not this year).
String shortDate(DateTime? at) {
  if (at == null) return '';
  return DateFormat(at.year == DateTime.now().year ? 'd MMM' : 'd MMM y').format(at);
}

/// "Tue, 12 Nov 2026".
String longDate(DateTime? at) => at == null ? '' : DateFormat('EEE, d MMM y').format(at);

/// "3:45 PM".
String clock(DateTime? at) => at == null ? '' : DateFormat('h:mm a').format(at);

/// "12 Nov, 3:45 PM".
String dateTime(DateTime? at) => at == null ? '' : '${shortDate(at)}, ${clock(at)}';

/// Chat day separator: "Today", "Yesterday", "Tue, 12 Nov".
String dayLabel(DateTime at) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(at);
}

/// How fast a technician usually answers: "~15 min", "~2 h", "~1 day".
String responseTime(double minutes) {
  if (minutes < 60) return '~${minutes.round().clamp(1, 59)} min';
  if (minutes < 24 * 60) return '~${(minutes / 60).round()} h';
  return '~${(minutes / 1440).round()} day${minutes >= 2880 ? 's' : ''}';
}

/// When a technician can start: 0 → "Today".
String etaLabel(int days) => days <= 0 ? 'Can start today' : (days == 1 ? 'Can start tomorrow' : 'Can start in $days days');

/// Time left until [at]: "2 days", "5 h", "now".
String timeLeft(DateTime? at) {
  if (at == null) return '';
  final d = at.difference(DateTime.now());
  if (d.isNegative) return 'now';
  if (d.inHours >= 48) return '${d.inDays} days';
  if (d.inHours >= 1) return '${d.inHours} h';
  return '${d.inMinutes.clamp(1, 59)} min';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Cleans an exception into a sentence a person can read.
String errorText(Object error) => error.toString().replaceFirst('Exception: ', '');

/// "850 m", "2.3 km", "12 km" — the same wording as the AI explanations.
String distance(num km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
