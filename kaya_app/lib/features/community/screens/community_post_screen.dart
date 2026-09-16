import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../providers/community_provider.dart';
import '../../moderation/widgets/report_sheet.dart';
import '../../../core/navigation/app_router.dart';

/*
    One post, in full, with the two things a reader can do: message the
    poster, or report it. The poster sees a Take down button instead.
*/
class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  late Map<String, dynamic> _post = widget.post;
  bool _busy = false;

  Map<String, dynamic> get _poster =>
      (_post['poster'] as Map?)?.cast<String, dynamic>() ?? const {};

  Future<void> _message() async {
    if (_busy) return;
    setState(() => _busy = true);

    final board = context.read<CommunityProvider>();
    final data = await board.contact(_post['id'] as int);

    if (!mounted) return;
    setState(() => _busy = false);

    if (data == null) {
      AppToast.error(context, board.error ?? 'Could not open the chat.');
      return;
    }

    final other = (data['other'] as Map?)?.cast<String, dynamic>() ?? const {};
    final myRole = (data['my_role'] ?? 'worker').toString();

    AppRouter.push(context, '/chat', arguments: {
      'conversationId': data['conversation_id'],
      'name': (other['name'] ?? _poster['name'] ?? '').toString(),
      'avatar': other['avatar'] ?? _poster['avatar'],
      // No job behind a board thread. The chat hides its job card and the
      // schedule button when there is none.
      'jobTitle': null,
      'jobId': data['job_id'],
      'otherUserId': other['id'] ?? _poster['id'],
      'isVerified': (other['is_verified'] as bool?) ?? false,
      'myRole': myRole,
      'otherRole': myRole == 'worker' ? 'employer' : 'worker',
    });
  }

  Future<void> _takeDown() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Take this post down?'),
        content: const Text('It leaves the board now. The Barya is not returned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Take down')),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final board = context.read<CommunityProvider>();
    final ok = await board.takeDown(_post['id'] as int);
    if (!mounted) return;

    if (ok) {
      setState(() => _post = {..._post, 'status': 'ended'});
      AppToast.success(context, 'Post taken down.');
    } else {
      AppToast.error(context, board.error ?? 'Could not take it down.');
    }
  }

  void _report() {
    final posterId = (_poster['id'] as num?)?.toInt();
    if (posterId == null) return;
    ReportSheet.show(
      context,
      reportedId: posterId,
      reportedName: (_poster['name'] ?? '').toString(),
      subjectType: 'community_post',
      subjectId: _post['id'] as int?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = _post['type'] == 'business';
    final isMine = _post['is_mine'] == true;
    final live = (_post['status'] ?? 'live') == 'live';
    final photo = _post['photo_url'] as String?;
    final daysLeft = (_post['days_left'] as num?)?.toInt();
    final where = (_post['location'] ?? '').toString();
    final category = (_post['category'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: Text(isBusiness ? 'Hiring' : 'Available for work',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          if (!isMine)
            IconButton(
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _report,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              ProfileAvatar(
                imageUrl: _poster['avatar'] as String?,
                name: _poster['name'] as String?,
                radius: 22,
                fallbackIcon: isBusiness ? Icons.business : Icons.person,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (_poster['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900),
                          ),
                        ),
                        if (_poster['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 15, color: AppColors.primary),
                        ],
                      ],
                    ),
                    Text(
                      [
                        if (category.isNotEmpty) category,
                        if (where.isNotEmpty) where,
                      ].join(', '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            (_post['title'] ?? '').toString(),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.neutral900, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(
            (_post['body'] ?? '').toString(),
            style: const TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.neutral700),
          ),
          if (photo != null && photo.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            !live
                ? 'This post has ended.'
                : daysLeft == null
                    ? ''
                    : daysLeft <= 0
                        ? 'Last day on the board.'
                        : '$daysLeft day${daysLeft == 1 ? '' : 's'} left on the board.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500),
          ),
          const SizedBox(height: 20),
          if (isMine && live)
            OutlinedButton(
              onPressed: _takeDown,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Take down'),
            )
          else if (!isMine && live)
            ElevatedButton.icon(
              onPressed: _busy ? null : _message,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text(isBusiness ? 'Message the business' : 'Message this worker'),
            ),
        ],
      ),
    );
  }
}
