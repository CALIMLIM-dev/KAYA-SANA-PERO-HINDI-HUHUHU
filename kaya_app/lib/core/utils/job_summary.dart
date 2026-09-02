/*
    The one-line facts a job card shows, formatted once.

    My Jobs and My Activity are two views of the same jobs, and they had drifted
    into two standards: the employer's card carried category, location, budget,
    applicant count and age, while the worker's carried a title and a name. The
    same app told the two sides of one hire different amounts about it, and the
    worker got the thinner half.

    Bringing them together means sharing the formatting, not copying it. A
    budget rendered "₱1200" on one screen and "₱1,200.00" on the other is the
    same class of bug as a count that disagrees with its list — two copies of a
    rule, only one of which gets updated.
*/

/// "₱1200", or "₱800 - ₱1200" when the range is real.
///
/// Returns null when the job carries no budget at all, so the caller can leave
/// the row out rather than print an empty peso sign.
String? formatBudget(Map<String, dynamic> job) {
  double? asDouble(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  final min = asDouble(job['budget_min']);
  final max = asDouble(job['budget_max']);

  if (min == null && max == null) return null;

  String fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  if (min != null && max != null && max != min) {
    return '₱${fmt(min)} - ₱${fmt(max)}';
  }
  return '₱${fmt(min ?? max!)}';
}

/// "just now", "5m ago", "3h ago", "2d ago", "4mo ago".
///
/// Null for an unparseable or missing date rather than a fallback string — a
/// card that cannot say when something happened should say nothing, not guess.
String? timeAgo(String? isoDate) {
  if (isoDate == null) return null;
  final date = DateTime.tryParse(isoDate);
  if (date == null) return null;

  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}
