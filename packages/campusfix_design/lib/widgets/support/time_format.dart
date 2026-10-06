/// Display rules for times (screens-spec G-8): relative under 24 hours
/// ("2 h ago"), otherwise an absolute date and time.
library;

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Absolute date and time, e.g. `6 Oct 2026, 14:05`.
String formatAbsoluteTime(DateTime at) =>
    '${at.day} ${_months[at.month - 1]} ${at.year}, '
    '${_two(at.hour)}:${_two(at.minute)}';

/// Relative under 24 hours ("Just now", "5 min ago", "3 h ago"), otherwise
/// [formatAbsoluteTime]. [now] is injectable so UI and tests are
/// deterministic.
String formatRelativeTime(DateTime at, {required DateTime now}) {
  final Duration age = now.difference(at);
  if (age < const Duration(minutes: 1)) return 'Just now';
  if (age < const Duration(hours: 1)) return '${age.inMinutes} min ago';
  if (age < const Duration(hours: 24)) return '${age.inHours} h ago';
  return formatAbsoluteTime(at);
}

/// A waiting duration without the "ago": `12 min`, `5 h` or `3 d`.
String formatWaiting(Duration waited) {
  if (waited < const Duration(minutes: 1)) return '<1 min';
  if (waited < const Duration(hours: 1)) return '${waited.inMinutes} min';
  if (waited < const Duration(hours: 24)) return '${waited.inHours} h';
  return '${waited.inDays} d';
}
