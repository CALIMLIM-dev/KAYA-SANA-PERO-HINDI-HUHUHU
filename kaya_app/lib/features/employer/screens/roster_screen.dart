import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/realtime_refresh.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../data/services/api_client.dart';

/*
    Everyone hired on one job, on one screen.

    A job for one person is run from its card and a chat. A job for five
    is not: five cards, five chats and five Mark Complete taps for the
    same afternoon's work. This lists them, marks them all done from the
    employer's side in one go, and sends one message into each of their
    own threads. Each worker still sees only their own thread.
*/
class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.jobId});

  final int jobId;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> with RealtimeRefresh {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _hires = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    bindRealtimeRefresh();
  }

  // A hire confirming their side, or withdrawing, changes this list.
  @override
  List<String> get refreshOn => const ['application.', 'job.'];

  @override
  void onRealtimeRefresh() => _load();

  Future<void> _load() async {
    try {
      final res = await _api.get('/jobs/${widget.jobId}/roster');
      final data = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _job = (data['job'] as Map).cast<String, dynamic>();
        _hires = ((data['hires'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int get _waitingOnMe => _hires.where((h) {
        final c = h['completion'] as Map?;
        return h['status'] == 'accepted' && c?['you_confirmed'] != true;
      }).length;

  Future<void> _completeAll() async {
    final count = _waitingOnMe;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark everyone complete?'),
        content: Text(
          'This marks your side done for $count worker${count == 1 ? '' : 's'}. '
          'Each of them still confirms their own, and the job closes when all have.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await _api.post('/jobs/${widget.jobId}/roster/complete');
      if (!mounted) return;
      AppToast.success(context, (res.data['message'] ?? 'Marked complete.').toString());
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _broadcast() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message all ${_hires.length} workers',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Goes into each of their chats with you. They do not see each other.',
              style: TextStyle(fontSize: 12.5, color: AppColors.neutral600, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Start is moved to 7 AM tomorrow.',
                filled: true,
                fillColor: AppColors.neutral50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neutral300),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(sheetContext, t);
                },
                child: const Text('Send to everyone'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await _api.post('/jobs/${widget.jobId}/roster/broadcast', data: {'message_text': text});
      if (!mounted) return;
      AppToast.success(context, (res.data['message'] ?? 'Sent.').toString());
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChat(Map<String, dynamic> hire) {
    final conversationId = hire['conversation_id'];
    if (conversationId == null) {
      AppToast.info(context, 'No chat with this worker yet.');
      return;
    }
    Navigator.pushNamed(context, '/chat', arguments: {
      'conversationId': conversationId,
      'name': (hire['name'] ?? 'Worker').toString(),
      'avatar': hire['avatar'],
      'jobTitle': _job?['title'],
      'jobId': widget.jobId,
      'otherUserId': hire['worker_id'],
      'isVerified': (hire['is_verified'] as bool?) ?? false,
      'applicationId': hire['application_id'],
      'jobStatus': _job?['status'],
      'myRole': 'employer',
      'otherRole': 'worker',
    });
  }

  @override
  Widget build(BuildContext context) {
    final needed = (_job?['workers_needed'] as num?)?.toInt() ?? 1;
    final filled = _hires.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: const Text('Roster', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral600)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Text(
                        (_job?['title'] ?? '').toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$filled of $needed hired'
                        '${_job?['status'] == 'completed' ? '. Finished.' : filled < needed ? '. Still taking applicants.' : '.'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
                      ),
                      const SizedBox(height: 16),
                      if (_hires.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Nobody hired yet. Accept applicants and they appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.neutral600, height: 1.4),
                          ),
                        ),
                      for (final hire in _hires) _hireRow(hire),
                      if (_hires.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _broadcast,
                                icon: const Icon(Icons.campaign_outlined, size: 18),
                                label: const Text('Message all'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _busy || _waitingOnMe == 0 ? null : _completeAll,
                                icon: const Icon(Icons.done_all, size: 18),
                                label: Text(_waitingOnMe == 0 ? 'All marked' : 'Mark all complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
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

  Widget _hireRow(Map<String, dynamic> hire) {
    final completion = (hire['completion'] as Map?)?.cast<String, dynamic>() ?? const {};
    final done = hire['status'] == 'completed';
    final mine = completion['you_confirmed'] == true;
    final theirs = completion['they_confirmed'] == true;
    final rating = (hire['rating_avg'] as num?)?.toDouble();
    final ratingCount = (hire['rating_count'] as num?)?.toInt() ?? 0;

    final String standing;
    final Color tint;
    if (done) {
      standing = 'Complete';
      tint = AppColors.success;
    } else if (mine && !theirs) {
      standing = 'Waiting for them to confirm';
      tint = AppColors.warning;
    } else if (theirs && !mine) {
      standing = 'They marked it done. Confirm.';
      tint = AppColors.primary;
    } else {
      standing = 'Working';
      tint = AppColors.neutral500;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          ProfileAvatar(imageUrl: hire['avatar'] as String?, name: hire['name'] as String?, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (hire['name'] ?? 'Worker').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.neutral900),
                      ),
                    ),
                    if (hire['is_verified'] == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (rating != null && ratingCount > 0) '${rating.toStringAsFixed(1)} ($ratingCount)',
                    standing,
                  ].join(', '),
                  style: TextStyle(fontSize: 12.5, color: tint, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Message',
            onPressed: () => _openChat(hire),
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
