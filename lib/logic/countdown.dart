/// Time until the next daily word — i.e. the next UTC midnight, since the daily
/// rolls over at UTC midnight (see WordRepository). Pure and testable.
Duration timeUntilNextDaily([DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  final nextMidnight =
      DateTime.utc(n.year, n.month, n.day).add(const Duration(days: 1));
  final d = nextMidnight.difference(n);
  return d.isNegative ? Duration.zero : d;
}

/// Formats a countdown as "14h 11m" (or "14h 11m 30s" with seconds).
String formatCountdown(Duration d, {bool withSeconds = false}) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return withSeconds ? '${h}h ${m}m ${s}s' : '${h}h ${m}m';
}
