import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/*
    Which days, and roughly when on them.

    The only availability that existed was one Available/Busy switch, which
    answers nothing an employer needs: somebody "available" might only ever be
    free on Sundays. This is the weekly pattern behind that switch.

    Periods rather than times, deliberately. A tradesperson says "weekends and
    weekday mornings", not "08:00 to 12:00", and a form with fourteen time
    pickers on it is a form nobody finishes. Ticking the whole day clears the
    parts of it, because saying both is the same as saying the wider one.

    Saved as a set: the server replaces the pattern with whatever is sent, so
    unticking a day removes it rather than leaving a row behind.
*/
class AvailabilityEditor extends StatefulWidget {
  const AvailabilityEditor({super.key});

  @override
  State<AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<AvailabilityEditor> {
  static const _days = [
    (index: 1, label: 'Mon'),
    (index: 2, label: 'Tue'),
    (index: 3, label: 'Wed'),
    (index: 4, label: 'Thu'),
    (index: 5, label: 'Fri'),
    (index: 6, label: 'Sat'),
    (index: 0, label: 'Sun'),
  ];

  static const _periods = [
    (value: 'morning', label: 'Morning'),
    (value: 'afternoon', label: 'Afternoon'),
    (value: 'evening', label: 'Evening'),
    (value: 'whole_day', label: 'Whole day'),
  ];

  final _api = ApiClient();

  /// day → the periods ticked on it.
  final Map<int, Set<String>> _pattern = {};

  bool _saving = false;

  /*
      Whether the person has started ticking.

      The form draws immediately - seven rows of chips need no data to
      exist - and the saved pattern fills in when it arrives. If they
      have already started answering by then, their answer wins: the
      same rule the setup screens use for prefill, and for the same
      reason, which is that overwriting somebody mid-tap looks like the
      app undoing their work.
  */
  bool _touched = false;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    /*
        Nothing to load without a session.

        Every provider in the app checks this before it touches the
        network - a request with no token is a round trip that can only
        fail, and it leaves a thirty second timeout timer running behind
        it. That timer outliving the screen is what a widget test reports
        as "a Timer is still pending after the widget tree was disposed".
    */
    try {
      // The token read can itself fail where there is no secure storage at
      // all, so it sits inside the try: an editor stuck on its spinner is a
      // worse outcome than an empty one.
      if (await ApiClient.getToken() == null) return;

      final res = await _api.get('/worker/availability');
      final data = res.data['data'] as Map<String, dynamic>;

      final rows = (data['availability'] as List?) ?? [];

      if (!mounted || _touched) return;

      setState(() {
        _pattern.clear();
        for (final row in rows.cast<Map<String, dynamic>>()) {
          final day = (row['day_of_week'] as num).toInt();
          _pattern.putIfAbsent(day, () => <String>{}).add(row['period'].toString());
        }
        _summary = data['summary'] as String?;
      });
    } catch (_) {
      // An empty pattern is a legitimate answer, and it is also what an
      // unreachable server should leave on screen: nothing claimed either way.
    }
  }

  /// The pattern as it stands, for a test. There is no other way to see
  /// what the form is about to send.
  @visibleForTesting
  Map<int, Set<String>> get debugPattern => _pattern;

  void _toggle(int day, String period) {
    setState(() {
      _touched = true;

      final periods = _pattern.putIfAbsent(day, () => <String>{});

      if (periods.contains(period)) {
        periods.remove(period);
      } else {
        // The wider answer wins: ticking the whole day clears the parts of
        // it, and ticking a part clears the whole day.
        if (period == 'whole_day') {
          periods.clear();
        } else {
          periods.remove('whole_day');
        }
        periods.add(period);
      }

      if (periods.isEmpty) _pattern.remove(day);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final rows = <Map<String, dynamic>>[];

    _pattern.forEach((day, periods) {
      for (final period in periods) {
        rows.add({'day_of_week': day, 'period': period});
      }
    });

    try {
      final res = await _api.put(
        '/worker/availability',
        data: {'availability': rows},
      );

      if (!mounted) return;

      setState(() {
        _summary = res.data['data']?['summary'] as String?;
        _saving = false;
      });

      AppToast.success(context, 'Availability saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summary == null || _summary!.isEmpty
              ? 'Employers see this on your profile, and it warns them before '
                  'they invite you to work on a day you did not tick.'
              : 'Employers see: $_summary',
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 12),
        ..._days.map(_dayRow),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save availability'),
          ),
        ),
      ],
    );
  }

  Widget _dayRow(({int index, String label}) day) {
    final periods = _pattern[day.index] ?? const <String>{};

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                day.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: periods.isEmpty
                      ? AppColors.neutral500
                      : AppColors.neutral900,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _periods.map((period) {
                final on = periods.contains(period.value);

                return GestureDetector(
                  onTap: () => _toggle(day.index, period.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: on ? AppColors.primary : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                        color:
                            on ? AppColors.primary : AppColors.neutral700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
