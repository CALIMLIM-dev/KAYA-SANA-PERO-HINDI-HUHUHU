import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';

/*
    The one calendar a post's last day is picked on.

    Each day says what ending there costs. The days an account does not have
    are locked, and tapping one offers the top up here, under the days. It
    starts at this week, not at the first of the month, so the free days and
    the first locked ones are always on the same page.
*/
class OpenUntilCalendar extends StatefulWidget {
  const OpenUntilCalendar({
    super.key,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.onTopUp,
    this.lastDay,
    this.priceFor,
  });

  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onTopUp;

  /// The last day this account can pick. Null: any.
  final DateTime? lastDay;

  /// What ending on a day costs, or null when it is not known or already paid.
  final int? Function(DateTime day)? priceFor;

  @override
  State<OpenUntilCalendar> createState() => _OpenUntilCalendarState();
}

class _OpenUntilCalendarState extends State<OpenUntilCalendar> {
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weeks = 5;
  static const _maxDays = 365;

  late int _page = _pageOf(widget.selected);

  /// The locked day that was tapped, while it is still locked.
  DateTime? _tapped;

  DateTime get _today => widget.today;

  /// The Sunday of this week.
  DateTime _at(int i) => DateTime(_today.year, _today.month, _today.day - _today.weekday % 7 + i);

  int _pageOf(DateTime? day) {
    if (day == null || day.isBefore(_today)) return 0;
    final start = _at(0);
    final days = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return days ~/ (_weeks * 7);
  }

  static bool _same(DateTime a, DateTime? b) => b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _locked(DateTime day) => widget.lastDay != null && day.isAfter(widget.lastDay!);

  @override
  void didUpdateWidget(OpenUntilCalendar old) {
    super.didUpdateWidget(old);
    // Filled in from a post after the first frame.
    if (old.selected == null && widget.selected != null) _page = _pageOf(widget.selected);
  }

  String _title(DateTime from, DateTime to) {
    final a = _months[from.month - 1];
    final b = _months[to.month - 1];
    if (from.year != to.year) return '$a ${from.year} - $b ${to.year}';
    return from.month == to.month ? '$a ${to.year}' : '$a - $b ${to.year}';
  }

  @override
  Widget build(BuildContext context) {
    final first = _page * _weeks * 7;
    final from = _page == 0 ? _today : _at(first);
    final to = _at(first + _weeks * 7 - 1);
    final end = DateTime(_today.year, _today.month, _today.day + _maxDays);
    final tapped = _tapped;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Earlier days',
                icon: const Icon(Icons.chevron_left),
                onPressed: _page == 0 ? null : () => setState(() => _page--),
              ),
              Expanded(
                child: Center(
                  child: _fit(
                    _title(from, to),
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neutral900),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Later days',
                icon: const Icon(Icons.chevron_right),
                onPressed: to.isBefore(end) ? () => setState(() => _page++) : null,
              ),
            ],
          ),
          Row(
            children: [
              for (final name in _weekdays)
                Expanded(
                  child: Center(
                    child: _fit(name, const TextStyle(fontSize: 11, color: AppColors.neutral500)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (var week = 0; week < _weeks; week++)
            Row(
              children: [
                for (var i = 0; i < 7; i++) Expanded(child: _day(_at(first + week * 7 + i), end)),
              ],
            ),
          if (tapped != null && _locked(tapped)) _topUp(tapped),
        ],
      ),
    );
  }

  Widget _topUp(DateTime day) => Container(
        margin: const EdgeInsets.fromLTRB(2, 6, 2, 0),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.neutral600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_months[day.month - 1].substring(0, 3)} ${day.day} needs a top up',
                style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
              ),
            ),
            TextButton(
              onPressed: widget.onTopUp,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Top Up'),
            ),
          ],
        ),
      );

  Widget _day(DateTime day, DateTime end) {
    final month = _months[day.month - 1].substring(0, 3);
    final label = '${_same(day, _today) || day.day == 1 ? '$month ' : ''}${day.day}';

    // Gone by, or past what a post can be.
    if (day.isBefore(_today) || day.isAfter(end)) {
      return _cell(label, ink: AppColors.neutral300);
    }

    final locked = _locked(day);
    final on = _same(day, widget.selected);
    // The days the post is open, up to the one picked.
    final open = !on && widget.selected != null && day.isBefore(widget.selected!);
    final price = locked ? null : widget.priceFor?.call(day);

    void tap() {
      setState(() => _tapped = locked ? day : null);
      if (!locked) widget.onSelected(day);
    }

    return Semantics(
      button: true,
      selected: on,
      label: '${_weekdays[day.weekday % 7]} $month ${day.day}${locked ? ', locked, needs a top up' : ''}',
      excludeSemantics: true,
      onTap: tap,
      child: InkWell(
        key: ValueKey('open-until-${day.year}-${day.month}-${day.day}'),
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: _cell(
          label,
          ink: on
              ? Colors.white
              : locked
                  ? AppColors.neutral400
                  : AppColors.neutral900,
          fill: on
              ? AppColors.primary
              : open
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : locked
                      ? AppColors.neutral100
                      : null,
          under: locked
              ? const Icon(Icons.lock_outline, size: 13, color: AppColors.neutral400)
              : price == null
                  ? null
                  : _fit(
                      price == 0 ? 'Free' : Credits.amount(price),
                      TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: on
                            ? Colors.white
                            : price == 0
                                ? AppColors.success
                                : AppColors.neutral700,
                      ),
                    ),
        ),
      ),
    );
  }

  static Widget _cell(String label, {required Color ink, Color? fill, Widget? under}) => Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            SizedBox(
              height: 19,
              child: _fit(label, TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink)),
            ),
            SizedBox(height: 15, child: under),
          ],
        ),
      );

  static Widget _fit(String text, TextStyle style) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: style));
}
