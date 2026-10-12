import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../core/widgets/profile_avatar.dart';

/*
    The person behind a notice, opened from their name or picture.

    Nothing on a notice led to who posted it, so a worker reading "Hiring"
    could not see who was hiring, and an employer reading "Available" could
    not see the worker's skills or reviews before answering. A worker's
    notice opens their worker profile; an employer's or a business's opens
    the employer profile.
*/
void openCommunityPoster(BuildContext context, Map<String, dynamic> post) {
  final poster = (post['poster'] as Map?)?.cast<String, dynamic>() ?? const {};
  final id = (poster['id'] as num?)?.toInt();
  if (id == null) return;

  if (post['type'] == 'worker') {
    AppRouter.push(context, AppRouter.workerProfile, arguments: {'workerId': id});
  } else {
    AppRouter.push(context, AppRouter.employerProfile, arguments: {'employerId': id});
  }
}

/*
    One notice on the board: who, what and where.

    The card opens the post, except the poster's picture and name, which
    open the poster.
*/
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({super.key, required this.post, required this.onTap});

  final Map<String, dynamic> post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final poster = (post['poster'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isBusiness = post['type'] == 'business';
    final photos = ((post['photo_urls'] as List?) ?? const [])
        .map((p) => p.toString())
        .where((p) => p.isNotEmpty)
        .toList();

    final photo = photos.isEmpty ? null : photos.first;
    final status = (post['status'] ?? 'live').toString();

    /*
        No countdown on a live post.

        "7 days left" sat on every notice. It is the poster's business how
        long they paid for, not the reader's, and a pill on every card is
        noise. What stays is what the author of the post must know about
        their own: waiting for review, not approved, removed or ended.
    */
    final String? pill = switch (status) {
      'live' => null,
      'pending' => 'Waiting for review',
      'rejected' => 'Not approved',
      'removed' => 'Removed',
      _ => 'Ended',
    };
    final comments = (post['comment_count'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openCommunityPoster(context, post),
                    child: Row(
                      children: [
                ProfileAvatar(
                  imageUrl: poster['avatar'] as String?,
                  name: poster['name'] as String?,
                  radius: 18,
                  fallbackIcon: isBusiness ? Icons.business : Icons.person,
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
                              (poster['name'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          VerificationChip(state: VerificationState.of(poster), size: 9.5),
                        ],
                      ),
                      Text(
                        [
                          isBusiness ? 'Hiring' : 'Available',
                        ].join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                      ),
                    ],
                  ),
                ),
                      ],
                    ),
                  ),
                ),
                if (pill != null) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    text: pill,
                    tint: status == 'pending'
                        ? AppColors.warning
                        : status == 'rejected'
                            ? AppColors.error
                            : AppColors.neutral500,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              (post['title'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (post['body'] ?? '').toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral700),
            ),
            // How busy the thread is, so a notice with questions under it
            // reads differently from one nobody has answered.
            if (comments > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.mode_comment_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 5),
                  Text(
                    '$comments comment${comments == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                  ),
                ],
              ),
            ],
            if (photos.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 5),
                  Text(
                    '${photos.length} photos',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                  ),
                ],
              ),
            ],
            if (photo != null && photo.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.neutral100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.neutral400),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tint),
      ),
    );
  }
}
