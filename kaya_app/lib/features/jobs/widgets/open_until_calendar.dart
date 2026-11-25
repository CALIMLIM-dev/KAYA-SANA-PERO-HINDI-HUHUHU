import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../core/widgets/top_up_strip.dart';
import '../../../providers/credits_provider.dart';

/*
    The day a post closes, on the same calendar as every other date.

    Below it: what the day picked costs, or that it is locked, and for an
    account that has not topped up, the day its locks start. A locked day can
    be looked at and not chosen.
*/
Future<DateTime?> pickOpenUntil(
  BuildContext context, {
  required DateTime today,
  required DateTime? selected,
  required DateTime? Function(CreditsProvider credits) lastDay,
  required int? Function(CreditsProvider credits, DateTime day) priceFor,
  required Future<void> Function() onTopUp,
}) =>
    showKayaPopup<DateTime>(
      context,
      builder: (_) => _OpenUntil(
        today: today,
        selected: selected,
        lastDay: lastDay,
        priceFor: priceFor,
        onTopUp: onTopUp,
      ),
    );

class _OpenUntil extends StatefulWidget {
  const _OpenUntil({
    required this.today,
    required this.selected,
    required this.lastDay,
    required this.priceFor,
    required this.onTopUp,
  });

  final DateTime today;
  final DateTime? selected;
  final DateTime? Function(CreditsProvider) lastDay;
  final int? Function(CreditsProvider, DateTime) priceFor;
  final Future<void> Function() onTopUp;

  @override
  State<_OpenUntil> createState() => _OpenUntilState();
}

class _OpenUntilState extends State<_OpenUntil> {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  late DateTime _day =
      widget.selected == null || widget.selected!.isBefore(widget.today) ? widget.today : widget.selected!;

  static String _short(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();
    final last = widget.lastDay(credits);
    final locked = last != null && _day.isAfter(last);
    final price = locked ? null : widget.priceFor(credits, _day);
    // A year ahead, and always far enough to show what is picked.
    final year = DateTime(widget.today.year, widget.today.month, widget.today.day + 365);
    final end = _day.isAfter(year) ? _day : year;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Open Until',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
          ),
          CalendarDatePicker(
            initialDate: _day,
            firstDate: widget.today,
            lastDate: end,
            currentDate: widget.today,
            onDateChanged: (day) => setState(() => _day = day),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_short(_day)}, ${_day.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900),
                  ),
                ),
                const SizedBox(width: 8),
                if (locked) ...[
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.neutral600),
                  const SizedBox(width: 4),
                  const Text('Locked',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.neutral600)),
                ] else if (price != null)
                  Text(
                    price == 0 ? 'Free' : Credits.amount(price),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: price == 0 ? AppColors.success : AppColors.neutral900,
                    ),
                  ),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 8),
            TopUpStrip(reason: 'Days after ${_short(last)} need a top up', onTopUp: widget.onTopUp),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: locked ? null : () => Navigator.pop(context, _day),
                child: const Text('OK'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
