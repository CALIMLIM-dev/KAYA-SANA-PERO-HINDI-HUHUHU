import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/schedule_provider.dart';

/*
    The day and time, as a card in the conversation.

    Three shapes have been tried here and two were wrong. Writing it into the
    thread as messages put words in people's mouths - "Proposed a schedule:
    Sat 13 Sep" is not something either of them typed. Hanging it above the
    keyboard as a one-line bar made the thing they are arranging read like a
    status line.

    So it is a card, sitting in the thread where the arranging happened, with
    the answer on it. It says what it is for, what was offered, and - when the
    worker has already agreed to something that day elsewhere - that they are
    unavailable, without saying a word about whose work that is.
*/
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.conversationId,
    required this.proposal,
    this.jobTitle,
    this.unavailable = false,
  });

  final int conversationId;

  /// The live offer, or the settled one. Shape as the server sends it.
  final Map<String, dynamic> proposal;

  final String? jobTitle;

  /// The worker has agreed to something else that day, in another thread.
  final bool unavailable;

  bool get _agreed => proposal['status'] == 'accepted';
  bool get _declined => proposal['status'] == 'declined';

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleProvider>();
    final me = context.read<AuthProvider>().user?['id'] as int?;

    // Nobody answers their own offer, so only one side is shown the buttons.
    final mine = proposal['proposed_by'] == me;
    final waiting = proposal['status'] == 'proposed';

    final note = (proposal['note'] as String?)?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _agreed ? AppColors.primary : AppColors.neutral200,
            width: _agreed ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _agreed
                      ? Icons.event_available
                      : _declined
                          ? Icons.event_busy_outlined
                          : Icons.event_outlined,
                  size: 15,
                  color: _agreed ? AppColors.primary : AppColors.neutral500,
                ),
                const SizedBox(width: 6),
                Text(
                  _agreed
                      ? 'AGREED'
                      : _declined
                          ? 'NOT THIS TIME'
                          : 'SCHEDULE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _agreed ? AppColors.primary : AppColors.neutral500,
                  ),
                ),
                const Spacer(),
                if (_agreed || _declined)
                  GestureDetector(
                    onTap: schedule.busy ? null : () => _change(context),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${proposal['summary']}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
            if (jobTitle != null && jobTitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                jobTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.neutral600),
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"$note"',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                  color: AppColors.neutral600,
                ),
              ),
            ],

            /*
                Said on the card, not only in the picker.

                Whoever is about to answer needs it as much as whoever offered:
                a worker with another job that day should see it before tapping
                "That works". It names nothing about the other work.
            */
            if (unavailable) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: AppColors.warning),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Unavailable that day - there is other work already '
                        'agreed.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.neutral700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (waiting) ...[
              const SizedBox(height: 10),
              if (mine)
                const Text(
                  'Waiting for them to answer',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: schedule.busy
                            ? null
                            : () => _respond(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
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
                            : () => _respond(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.neutral700,
                          side: const BorderSide(color: AppColors.neutral300),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text("I can't"),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respond(BuildContext context, bool accept) async {
    final schedule = context.read<ScheduleProvider>();

    final ok = await schedule.respond(
      conversationId,
      proposal['id'] as int,
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

  /// Changing an agreed day is just proposing another one, which the other
  /// side answers in turn.
  void _change(BuildContext context) => ScheduleComposer.open(
        context,
        conversationId: conversationId,
        jobId: proposal['job_id'] as int?,
      );
}

/*
    The day and time picker, opened from the calendar button beside the message
    box or from Change on the card.

    Two pickers and a line: the phone already has both, and a day and an hour
    are the two things anybody arranging work actually says. No parts of the
    day - "Saturday morning" was the vocabulary of a weekly availability
    pattern, and these two are settling one job.
*/
class ScheduleComposer {
  const ScheduleComposer._();

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 24-hour `HH:mm`, the only shape the server accepts. `TimeOfDay.format`
  /// follows the phone's locale and would send "8:00 AM" on a 12-hour device.
  static String _apiTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static Future<void> open(
    BuildContext context, {
    required int conversationId,
    int? jobId,
  }) async {
    final schedule = context.read<ScheduleProvider>();
    final busyDays = schedule
        .busyFor(conversationId)
        .map((row) => row['date'].toString())
        .toSet();

    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Which day?',
    );

    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'What time?',
    );

    if (time == null || !context.mounted) return;

    // Already agreed to something that day, in another thread. Not a refusal -
    // it is what the sheet has to say out loud before anybody sends.
    final taken = busyDays.contains(_dateKey(date));

    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
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
            Row(
              children: [
                const Icon(Icons.event_outlined,
                    size: 17, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_dayLabel(date)} at ${time.format(sheetContext)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
              ],
            ),
            if (taken) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.warning),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'They are unavailable that day. You can still send '
                        'this and see what they say.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.neutral700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await schedule.propose(
      conversationId,
      date: date,
      time: _apiTime(time),
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
