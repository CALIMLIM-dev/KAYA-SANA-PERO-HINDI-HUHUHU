import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';

/*
    The days a post can stay open, as days.

    A post's limit was only met by running into it: the calendar ran a year,
    and an account that had never topped up was refused after pressing Post.
    Here the days it has are days, and the ones past them are locked.
*/
class OpenUntilDays extends StatelessWidget {
  const OpenUntilDays({
    super.key,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.onLocked,
    this.lastDay,
    this.priceFor,
  });

  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onLocked;

  /// The last day this account can pick. Null: any.
  final DateTime? lastDay;

  /// What ending on a day costs, or null when the price is not known yet.
  final int? Function(DateTime day)? priceFor;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Weeks shown, all at once: swiping to find a lock is finding it late.
  /// Later days are on the calendar.
  static const _weeks = 3;

  static bool _same(DateTime a, DateTime? b) => b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _at(int i) => DateTime(today.year, today.month, today.day + i);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _fit(
                    _weekdays[_at(i).weekday - 1],
                    const TextStyle(fontSize: 11, color: AppColors.neutral500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (var week = 0; week < _weeks; week++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(child: _day(_at(week * 7 + i), first: week == 0 && i == 0)),
              ],
            ),
        ],
      );

  Widget _day(DateTime day, {required bool first}) {
    final locked = lastDay != null && day.isAfter(lastDay!);
    final on = _same(day, selected);
    final price = locked ? null : priceFor?.call(day);
    final month = _months[day.month - 1];
    final ink = on
        ? Colors.white
        : locked
            ? AppColors.neutral400
            : AppColors.neutral900;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        selected: on,
        label: '${_weekdays[day.weekday - 1]} $month ${day.day}${locked ? ', locked, top up' : ''}',
        excludeSemantics: true,
        onTap: locked ? onLocked : () => onSelected(day),
        child: InkWell(
          key: ValueKey('open-until-${day.year}-${day.month}-${day.day}'),
          onTap: locked ? onLocked : () => onSelected(day),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.primary
                  : locked
                      ? AppColors.neutral100
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: on
                    ? AppColors.primary
                    : locked
                        ? AppColors.neutral100
                        : AppColors.neutral300,
              ),
            ),
            child: Column(
              children: [
                // The month where one starts, and on the first day shown.
                SizedBox(
                  height: 20,
                  child: _fit(
                    '${first || day.day == 1 ? '$month ' : ''}${day.day}',
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: locked
                      ? const Icon(Icons.lock_outline, size: 14, color: AppColors.neutral400)
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _fit(String text, TextStyle style) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: style));
}
