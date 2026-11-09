const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 14, 2026", or "Oct 14, 2026, 3:05 PM" with [time].
String formatModerationDate(Object? iso, {bool time = false}) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final day = '${_months[d.month - 1]} ${d.day}, ${d.year}';
  if (!time) return day;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$day, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}
