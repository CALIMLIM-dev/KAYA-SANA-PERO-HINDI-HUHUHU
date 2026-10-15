import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../data/services/api_client.dart';
import '../../moderation/widgets/report_sheet.dart';
import 'completion_action.dart';

/*
    What a live hire can still do besides finish: Cancel Job, answer a
    request to cancel, or Report a Problem when the other side marked it
    complete and the work was not done.

    One widget for the four places a hire is shown - the worker's card, the
    employer's job card, the applicant list and the roster - all reading the
    same `hire_actions` block the server sends (HireCancellation::actions),
    so they cannot disagree about what is allowed.
*/
class HireControls extends StatelessWidget {
  const HireControls({
    super.key,
    required this.actions,
    required this.applicationId,
    required this.otherName,
    required this.otherId,
    required this.onChanged,
  });

  final Map<String, dynamic> actions;
  final int applicationId;
  final String otherName;
  final int? otherId;
  final Future<void> Function() onChanged;

  /// The controls, or null when this hire has nothing to offer here.
  static Widget? maybe({
    required Object? actions,
    required Object? applicationId,
    required String otherName,
    required Object? otherId,
    required Future<void> Function() onChanged,
  }) {
    if (actions is! Map || applicationId is! num) return null;
    final a = Map<String, dynamic>.from(actions);
    final any = a['cancel'] != null ||
        a['disputed'] == true ||
        a['can_cancel'] == true ||
        a['can_dispute'] == true;

    return any
        ? HireControls(
            actions: a,
            applicationId: applicationId.toInt(),
            otherName: otherName,
            otherId: otherId is num ? otherId.toInt() : null,
            onChanged: onChanged,
          )
        : null;
  }

  Future<void> _after(BuildContext context) async {
    await refreshActivity(context);
    if (context.mounted) await onChanged();
  }

  Future<void> _call(BuildContext context, Future<dynamic> Function() request, String done) async {
    try {
      await request();
      if (!context.mounted) return;
      AppToast.success(context, done);
      await _after(context);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _agree(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel the Job?'),
        content: Text('Your job with $otherName will be cancelled. It will not count against either of you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not Now')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Agree to Cancel')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;

    await _call(context, () => ApiClient().post('/applications/$applicationId/cancel/agree'), 'Job cancelled.');
  }

  Future<void> _cancel(BuildContext context) async {
    final sent = await showKayaPopup<bool>(
      context,
      builder: (_) => _CancelHireForm(applicationId: applicationId, otherName: otherName),
    );
    if (sent == true && context.mounted) await _after(context);
  }

  Future<void> _dispute(BuildContext context) async {
    final id = otherId;
    if (id == null) return;

    await ReportSheet.show(
      context,
      reportedId: id,
      reportedName: otherName,
      subjectType: 'application',
      subjectId: applicationId,
      initialReason: 'work_not_done',
    );
    if (context.mounted) await _after(context);
  }

  @override
  Widget build(BuildContext context) {
    final cancel = actions['cancel'] is Map ? Map<String, dynamic>.from(actions['cancel'] as Map) : null;

    if (cancel != null) {
      final mine = cancel['mine'] == true;
      final when = _when(cancel['cancels_at']);
      final note = (cancel['note'] ?? '').toString();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine ? 'You asked to cancel. Reason: ${cancel['reason']}.' : '$otherName asked to cancel. Reason: ${cancel['reason']}.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral800),
          ),
          if (!mine && note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('"$note"', style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.neutral600)),
          ],
          const SizedBox(height: 2),
          Text(
            mine ? 'Cancels on $when if $otherName does not answer.' : 'Cancels on $when if you do not answer.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
          ),
          _link(
            mine ? 'Undo Request' : 'Agree to Cancel',
            mine
                ? () => _call(context, () => ApiClient().delete('/applications/$applicationId/cancel'), 'Cancel request removed.')
                : () => _agree(context),
          ),
        ],
      );
    }

    if (actions['disputed'] == true) {
      return const Text(
        'A problem was reported. KAYA will review it.',
        style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
      );
    }

    return Wrap(
      spacing: 16,
      children: [
        if (actions['can_dispute'] == true) _link('Report a Problem', () => _dispute(context)),
        if (actions['can_cancel'] == true) _link('Cancel Job', () => _cancel(context)),
      ],
    );
  }

  Widget _link(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.neutral700,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _when(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return 'soon';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${_months[d.month - 1]} ${d.day}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Why, and an optional word to the other side.
class _CancelHireForm extends StatefulWidget {
  const _CancelHireForm({required this.applicationId, required this.otherName});

  final int applicationId;
  final String otherName;

  @override
  State<_CancelHireForm> createState() => _CancelHireFormState();
}

class _CancelHireFormState extends State<_CancelHireForm> {
  static const _reasons = {
    'pay': 'Could Not Agree on Pay',
    'schedule': 'Schedule Conflict',
    'no_show': 'Did Not Show Up',
    'other': 'Something Else',
  };

  final TextEditingController _note = TextEditingController();
  String? _reason;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final res = await ApiClient().post('/applications/${widget.applicationId}/cancel', data: {
        'reason': _reason,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.success(context, (res.data['message'] ?? 'Done.').toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cancel Job', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) {
              if (!_sending) setState(() => _reason = v);
            },
            child: Column(
              children: [
                for (final entry in _reasons.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 280,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not Now')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending || _reason == null ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Cancel Job'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
