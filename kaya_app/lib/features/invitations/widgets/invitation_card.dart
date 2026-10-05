import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../../core/utils/job_summary.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verify_gate.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/invitation_provider.dart';

/*
    One invitation, as the worker sees it.

    There were two of these - a full card on My Invitations and a two-line
    one in My Activity's Invited sheet that said only the job's title and
    who sent it - so the place most people open showed the least. One card
    now, used by both.

    Everything a worker needs to say yes from the card: who is asking (the
    business name for a company), the trade, the pay and its period, where,
    when, how many people the job is for, and the start of the description.
    The street address is not here and is not sent: it comes with the hire.
*/
class InvitationCard extends StatefulWidget {
  const InvitationCard({super.key, required this.invitation});

  final Map<String, dynamic> invitation;

  @override
  State<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<InvitationCard> {
  bool _busy = false;

  Map<String, dynamic> get _inv => widget.invitation;
  Map<String, dynamic>? get _job => _inv['job'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _employer => _inv['employer'] as Map<String, dynamic>?;
  String get _jobTitle => (_job?['title'] ?? 'this job').toString();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final status = (_inv['status'] ?? 'pending').toString();
    final job = _job;
    final employer = _employer;

    final employerName = (employer?['name'] ?? 'An employer').toString();
    final personName = (employer?['person_name'] ?? '').toString();
    final isCompany = employer?['is_company'] == true;
    final verified = employer?['is_verified'] == true;
    final avatar = ApiClient.fileUrl(employer?['avatar']?.toString());

    final category = (job?['category'] ?? '').toString();
    final place = [job?['location'], job?['city']]
        .map((v) => (v ?? '').toString().trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final budget = job == null ? null : formatBudget(job);
    final period = _period((job?['budget_period'] ?? '').toString());
    final schedule = _schedule(job);
    final spots = (job?['workers_needed'] as num?)?.toInt() ?? 1;
    final description = (job?['description'] ?? '').toString().trim();
    final sent = timeAgo(_inv['created_at']?.toString());
    final stillOpen = job?['is_open'] != false;
    final pending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Who is asking.
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isNotEmpty
                      ? null
                      : Icon(isCompany ? Icons.business : Icons.person,
                          size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employerName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: AppColors.success),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if (isCompany && personName.isNotEmpty) personName,
                          if (sent != null) 'Invited you $sent',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _statusBadge(status, stillOpen),
              ],
            ),
            const SizedBox(height: 12),

            // The job.
            Text(
              _jobTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
                height: 1.25,
              ),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _fact(
              Icons.payments_outlined,
              budget == null
                  ? 'Payment to be discussed'
                  : period == null ? budget : '$budget $period',
              strong: budget != null,
            ),
            if (place.isNotEmpty) _fact(Icons.location_on_outlined, place),
            if (schedule != null) _fact(Icons.event_outlined, schedule),
            if (spots > 1) _fact(Icons.group_outlined, 'For $spots people'),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.neutral600,
                ),
              ),
            ],

            if (pending && !stillOpen) ...[
              const SizedBox(height: 10),
              _note('This job is no longer taking people. You can decline it.'),
            ],

            const SizedBox(height: 12),
            if (_busy)
              const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ..._actions(status, stillOpen),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(String status, bool stillOpen) {
    final jobId = (_job?['id'] as num?)?.toInt();

    final viewJob = OutlinedButton(
      onPressed: jobId == null
          ? null
          : () => AppRouter.push(context, AppRouter.jobDetails,
              arguments: {'jobId': jobId}),
      style: _outlined(AppColors.primary),
      child: const Text('View job'),
    );

    if (status == 'pending') {
      return [
        Row(
          children: [
            Expanded(child: viewJob),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmDecline,
                style: _outlined(AppColors.neutral600),
                child: const Text('Decline'),
              ),
            ),
            if (stillOpen) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ],
        ),
      ];
    }

    if (status == 'accepted') {
      return [
        Row(
          children: [
            Expanded(child: viewJob),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _message,
                icon: const Icon(Icons.message_outlined, size: 16),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    return [SizedBox(width: double.infinity, child: viewJob)];
  }

  /// Straight into the thread with this employer, or the inbox when the
  /// server has none to point at (the job finished and the thread closed).
  void _message() {
    final conversationId = (_inv['conversation_id'] as num?)?.toInt();
    if (conversationId == null) {
      MainNavigation.openMessages(context);
      return;
    }
    _openChat(conversationId);
  }

  void _openChat(int conversationId) {
    final employer = _employer;
    AppRouter.push(context, AppRouter.chat, arguments: {
      'conversationId': conversationId,
      'name': employer?['name'] ?? 'Employer',
      'jobTitle': _jobTitle,
      'jobId': _job?['id'],
      'otherUserId': employer?['id'],
      'isVerified': employer?['is_verified'] ?? false,
      'otherRole': 'employer',
    });
  }

  Future<void> _confirmAccept() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept invitation?'),
        content: Text('You will be hired for "$_jobTitle" and can message the employer after.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Accepting is gated server side, so ask before the spinner rather than
    // after the refusal.
    if (!await ensureVerified(context, action: 'accept an invitation')) return;
    if (!mounted) return;

    setState(() => _busy = true);
    final provider = context.read<InvitationProvider>();
    final conversationId = await provider.accept(_inv['id'] as int);
    if (!mounted) return;
    setState(() => _busy = false);

    if (conversationId == null) {
      AppToast.error(context, provider.takeActionError() ?? 'Could not accept the invitation.');
      return;
    }

    AppToast.show(
      context,
      'Invitation accepted',
      type: ToastType.success,
      duration: const Duration(seconds: 4),
      actionLabel: 'Message',
      onAction: () => _openChat(conversationId),
    );
  }

  Future<void> _confirmDecline() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline invitation?'),
        content: Text('Decline the invitation for "$_jobTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neutral600),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<InvitationProvider>();
    final success = await provider.decline(_inv['id'] as int);
    if (!mounted) return;
    setState(() => _busy = false);

    if (success) {
      AppToast.info(context, 'Invitation declined');
    } else {
      AppToast.error(context, provider.takeActionError() ?? 'Could not decline the invitation.');
    }
  }

  // ─── pieces ────────────────────────────────────────────────────────────────

  Widget _fact(IconData icon, String text, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: strong ? AppColors.primary : AppColors.neutral500),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                  color: strong ? AppColors.primary : AppColors.neutral700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _note(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 15, color: AppColors.neutral600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral700)),
            ),
          ],
        ),
      );

  ButtonStyle _outlined(Color color) => OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color == AppColors.primary ? AppColors.primary : AppColors.neutral300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      );

  /// Every status the server writes has its own word. Anything that was not
  /// pending or accepted used to read "Declined", including a job that had
  /// simply closed.
  Widget _statusBadge(String status, bool stillOpen) {
    final (Color color, String label) = switch (status) {
      'pending' when !stillOpen => (AppColors.neutral500, 'Closed'),
      'pending' => (AppColors.warning, 'Pending'),
      'accepted' => (AppColors.success, 'Accepted'),
      'declined' => (AppColors.neutral500, 'Declined'),
      _ => (AppColors.neutral500, 'Closed'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  /// "per day", "per hour", "contract".
  String? _period(String raw) => switch (raw) {
        'daily' || 'day' => 'per day',
        'hourly' || 'hour' => 'per hour',
        'project' => 'contract',
        _ => null,
      };

  /// "Oct 8", "Oct 8 – 12", "Oct 30 – Nov 2", with the start time on a
  /// single day. Null for a job posted before scheduling existed.
  String? _schedule(Map<String, dynamic>? job) {
    final start = DateTime.tryParse('${job?['start_date']}');
    if (start == null) return null;
    final end = DateTime.tryParse('${job?['end_date']}');

    String short(DateTime d) => '${_months[d.month - 1]} ${d.day}';

    if (end != null && !(end.year == start.year && end.month == start.month && end.day == start.day)) {
      return end.year == start.year && end.month == start.month
          ? '${short(start)} – ${end.day}'
          : '${short(start)} – ${short(end)}';
    }

    final time = (job?['start_time'] ?? '').toString();
    return time.isEmpty ? short(start) : '${short(start)}, ${_clock(time)}';
  }

  /// "08:30:00" as "8:30 AM".
  String _clock(String raw) {
    final parts = raw.split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length > 1 ? parts[1] : '00';
    if (h == null) return raw;
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m ${h < 12 ? 'AM' : 'PM'}';
  }
}
