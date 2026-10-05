import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../providers/credits_provider.dart';

/*
    Where the Barya went.

    This was one long column of "Applied to a job  -2" with the raw database
    word for anything it did not recognise. Now: what came in and went out
    this month, a filter, and the lines grouped by day - each with what it
    was, when, and the balance it left.
*/
class WalletHistory extends StatefulWidget {
  const WalletHistory({
    super.key,
    required this.entries,
    required this.loading,
    this.pageSize = CreditsProvider.historyPageSize,
    this.previewRows,
  });

  final List<CreditEntry> entries;
  final bool loading;

  /// How many lines the server sends. A month's totals are only shown when
  /// the list reaches back past the start of the month, or is shorter than a
  /// page - otherwise they would quietly leave out what was not loaded.
  final int pageSize;

  /// The wallet's short version: the newest lines only, no totals or
  /// filter. Null is the full history screen.
  final int? previewRows;

  @override
  State<WalletHistory> createState() => _WalletHistoryState();
}

enum _Filter { all, received, spent }

class _WalletHistoryState extends State<WalletHistory> {
  _Filter _filter = _Filter.all;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;

    if (widget.loading && entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (entries.isEmpty) {
      return _emptyCard('Nothing yet. Applying to a job will show up here.');
    }

    if (widget.previewRows != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _groups(entries.take(widget.previewRows!).toList()),
      );
    }

    final shown = entries.where((e) => switch (_filter) {
          _Filter.all => true,
          _Filter.received => e.isCredit,
          _Filter.spent => !e.isCredit,
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_monthTotals(entries) case (final inc, final out)) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'This month',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _total('Received', '+$inc', AppColors.success, Icons.south_west)),
              const SizedBox(width: 10),
              Expanded(child: _total('Spent', '-$out', AppColors.neutral900, Icons.north_east)),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('All', _Filter.all),
            _chip('Received', _Filter.received),
            _chip('Spent', _Filter.spent),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          _emptyCard(_filter == _Filter.received
              ? 'Nothing received in this list.'
              : 'Nothing spent in this list.')
        else
          ..._groups(shown),
      ],
    );
  }

  /// This month's in and out, or null when the list may not cover it.
  (int, int)? _monthTotals(List<CreditEntry> entries) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);

    final reachesBack = entries.length < widget.pageSize ||
        entries.any((e) => e.createdAt != null && e.createdAt!.toLocal().isBefore(start));
    if (!reachesBack) return null;

    var inc = 0;
    var out = 0;
    for (final e in entries) {
      final at = e.createdAt?.toLocal();
      if (at == null || at.isBefore(start)) continue;
      if (e.isCredit) {
        inc += e.delta;
      } else {
        out += -e.delta;
      }
    }
    return (inc, out);
  }

  List<Widget> _groups(List<CreditEntry> entries) {
    final groups = <String, List<CreditEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(_dayLabel(e.createdAt?.toLocal()), () => []).add(e);
    }

    return [
      for (final MapEntry(key: day, value: rows) in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Text(
            day,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64, color: AppColors.neutral200),
                _row(rows[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _row(CreditEntry entry) {
    final positive = entry.isCredit;
    final tint = positive ? AppColors.success : AppColors.primary;
    final time = _time(entry.createdAt?.toLocal());
    final subtitle = [
      if (entry.note != null && entry.note!.trim().isNotEmpty) entry.note!.trim(),
      if (time.isNotEmpty) time,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Credits.iconFor(entry.reason, isRefund: entry.isRefund),
              size: 19,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Credits.describe(entry.reason, isRefund: entry.isRefund),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                positive ? '+${entry.delta}' : '${entry.delta}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: positive ? AppColors.success : AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Balance ${entry.balanceAfter}',
                style: const TextStyle(fontSize: 11, color: AppColors.neutral500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _total(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.neutral500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value ${Credits.plural}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.neutral700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.neutral300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
    );
  }

  String _dayLabel(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final base = '${_days[at.weekday - 1]}, ${at.day} ${_months[at.month - 1]}';
    return at.year == now.year ? base : '$base ${at.year}';
  }

  String _time(DateTime? at) {
    if (at == null) return '';
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
  }
}
