import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/schedule_provider.dart';

/*
    The day the two of them agree on, in the thread where they agree it.

    A schedule is not a routine on somebody's profile - that says what a person
    usually does, and nobody has to accept it. This is an arrangement: one side
    offers a day and a part of it, the other says yes or no, and both sides see
    the same answer. Either can propose, because a worker offering Saturday and
    an employer asking for Saturday are the same sentence.

    The job post still owns when the work runs. This owns when these two meet
    for it.
*/
class ScheduleStrip extends StatelessWidget {
  const ScheduleStrip({
    super.key,
    required this.conversationId,
    this.jobId,
  });

  final int conversationId;
  final int? jobId;

  static const _periods = [
    (value: 'morning', label: 'Morning'),
    (value: 'afternoon', label: 'Afternoon'),
    (value: 'evening', label: 'Evening'),
    (value: 'whole_day', label: 'Whole day'),
  ];

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleProvider>();
    final me = context.read<AuthProvider>().user?['id'] as int?;

    final pending = schedule.pendingFor(conversationId);
    final agreed = schedule.agreedFor(conversationId);

    // Waiting on the other person is not the same as waiting on you. Only one
    // of the two gets buttons.
    final mine = pending != null && pending['proposed_by'] == me;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 15, color: AppColors.neutral600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  agreed != null
                      ? 'Agreed: ${agreed['summary']}'
                      : pending != null
                          ? (mine
                              ? 'Waiting on them: ${pending['summary']}'
                              : 'They proposed ${pending['summary']}')
                          : 'No day agreed yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        agreed != null ? FontWeight.w600 : FontWeight.w500,
                    color: agreed != null
                        ? AppColors.neutral900
                        : AppColors.neutral700,
                  ),
                ),
              ),
              TextButton(
                onPressed: schedule.busy
                    ? null
                    : () => _openProposeSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  agreed != null || pending != null ? 'Change' : 'Propose a day',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),

          // The note travels with the offer: "bring your own tools" is the
          // kind of thing that decides whether the day works.
          if (pending != null &&
              (pending['note'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Text(
                pending['note'].toString(),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral600),
              ),
            ),
          ],

          if (pending != null && !mine) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: schedule.busy
                        ? null
                        : () => _respond(context, pending['id'] as int, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('That works'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: schedule.busy
                        ? null
                        : () => _respond(context, pending['id'] as int, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                      side: const BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('I cannot'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, int proposalId, bool accept) async {
    final schedule = context.read<ScheduleProvider>();

    final ok = await schedule.respond(
      conversationId,
      proposalId,
      accept: accept,
    );

    if (!context.mounted) return;

    if (ok) {
      AppToast.success(
        context,
        accept ? 'Schedule agreed' : 'Let them know what suits you instead',
      );
    } else {
      AppToast.error(context, schedule.errorMessage ?? 'Could not answer that.');
    }
  }

  /*
      Day, part of the day, and an optional line.

      No time picker: "Saturday morning" is what people actually agree to, and
      an exact hour collects a precision nobody keeps - the same reason the
      job post stopped asking for one.
  */
  Future<void> _openProposeSheet(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Which day?',
    );

    if (date == null || !context.mounted) return;

    final noteController = TextEditingController();
    var period = 'morning';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What time on ${_dayLabel(date)}?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _periods.map((p) {
                  final on = period == p.value;

                  return GestureDetector(
                    onTap: () => setSheetState(() => period = p.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.neutral100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: on ? AppColors.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                          color:
                              on ? AppColors.primary : AppColors.neutral700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLength: 280,
                decoration: InputDecoration(
                  hintText: 'Anything they should know (optional)',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.neutral100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Send this to them'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final schedule = context.read<ScheduleProvider>();

    final ok = await schedule.propose(
      conversationId,
      date: date,
      period: period,
      note: noteController.text,
      jobId: jobId,
    );

    if (!context.mounted) return;

    if (ok) {
      AppToast.success(context, 'Sent. They can accept it or say no.');
    } else {
      AppToast.error(context, schedule.errorMessage ?? 'Could not send that.');
    }
  }

  static String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }
}
