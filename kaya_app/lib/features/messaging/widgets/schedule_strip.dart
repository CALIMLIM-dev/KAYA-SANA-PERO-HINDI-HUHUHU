import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/schedule_provider.dart';

/*
    The day and time the two of them agree on, beside where they type.

    A panel, not messages. Proposing used to write "Proposed a schedule..."
    into the thread and accepting wrote another line under it - three messages
    nobody typed, for something that is not really conversation. This holds the
    state; the thread stays theirs.

    It also shows the days the worker has already agreed to elsewhere. Shown,
    never enforced: the day is marked unavailable and the offer can still be
    sent. The two people in a conversation know things the server does not -
    work moves, hours get swapped - and what is not acceptable is booking
    somebody already committed without ever being told.

    What it never says is what the other work is. That an employer's worker is
    taken is this employer's business; whose job it is, is not.
*/
class ScheduleStrip extends StatefulWidget {
  const ScheduleStrip({
    super.key,
    required this.conversationId,
    this.jobId,
  });

  final int conversationId;
  final int? jobId;

  @override
  State<ScheduleStrip> createState() => _ScheduleStripState();
}

class _ScheduleStripState extends State<ScheduleStrip> {
  int get conversationId => widget.conversationId;
  int? get jobId => widget.jobId;

  /*
      Loaded once, when the panel appears.

      It used to be fetched from the chat screen's own startup, which meant a
      thread with no job still asked for a schedule it would never show. The
      app polls for messages as its transport because Reverb is off, and that
      is already close to the rate limit - an extra request per thread open is
      not free.
  */
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScheduleProvider>().load(conversationId);
    });
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 24-hour `HH:mm`, the only shape the server accepts. `TimeOfDay.format`
  /// follows the phone's locale and would send "8:00 AM" on a 12-hour device.
  static String _apiTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleProvider>();
    final me = context.read<AuthProvider>().user?['id'] as int?;

    final pending = schedule.pendingFor(conversationId);
    final agreed = schedule.agreedFor(conversationId);

    // Waiting on them is not the same as waiting on you. Only one side gets
    // the buttons.
    final mine = pending != null && pending['proposed_by'] == me;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                agreed != null ? Icons.event_available : Icons.event_outlined,
                size: 15,
                color:
                    agreed != null ? AppColors.primary : AppColors.neutral600,
              ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        agreed != null ? FontWeight.w600 : FontWeight.w500,
                    color: agreed != null
                        ? AppColors.neutral900
                        : AppColors.neutral700,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    schedule.busy ? null : () => _openProposeSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  agreed != null || pending != null ? 'Change' : 'Set a time',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (pending != null && !mine) ...[
            const SizedBox(height: 6),
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
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
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
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
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

  Future<void> _respond(
      BuildContext context, int proposalId, bool accept) async {
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
      A day, an hour, and an optional line.

      Two pickers rather than a form: the phone already has both, and they are
      the two things anybody arranging work actually says.
  */
  Future<void> _openProposeSheet(BuildContext context) async {
    final schedule = context.read<ScheduleProvider>();
    final busyDays =
        schedule.busyFor(conversationId).map((r) => r['date'].toString()).toSet();

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

    // Already agreed to something that day, in another thread. Not a refusal:
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
