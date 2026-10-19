import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../providers/community_provider.dart';

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
      'pending' => 'Waiting for Review',
      'rejected' => 'Not Approved',
      'removed' => 'Removed',
      _ => 'Ended',
    };
    final comments = (post['comment_count'] as num?)?.toInt() ?? 0;
    final live = status == 'live';

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
            // Your own post off the board: how busy its thread got. A live
            // post says this in the footer instead.
            if (!live && comments > 0) ...[
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
                    // Decoded at the card's width, not the 1600 it went up at.
                    cacheWidth: (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.neutral100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.neutral400),
                    ),
                  ),
                ),
              ),
            ],
            // Likes and how busy the thread is, on every live notice, so one
            // with questions under it reads differently from one nobody has
            // answered. Tapping the count opens the post, like the card.
            if (live) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  CommunityLikeButton(post: post),
                  const SizedBox(width: 12),
                  const Icon(Icons.mode_comment_outlined,
                      size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 6),
                  Text(
                    '$comments',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/*
    The like on a notice: a thumb and how many. Filled when you have liked
    it. It changes the moment it is tapped and goes back if the server
    refuses, so a slow connection does not make it feel broken.
*/
class CommunityLikeButton extends StatelessWidget {
  const CommunityLikeButton({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final board = context.watch<CommunityProvider>();
    final like = board.likeOf(post);

    return Semantics(
      button: true,
      label: like.liked ? 'Unlike' : 'Like',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final ok = await board.toggleLike(post);
          if (!ok && context.mounted) {
            AppToast.error(context, board.error ?? 'Could not like that.');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                like.liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 16,
                color: like.liked ? AppColors.primary : AppColors.neutral500,
              ),
              const SizedBox(width: 6),
              Text(
                '${like.count}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: like.liked ? FontWeight.w600 : FontWeight.w400,
                  color: like.liked ? AppColors.primary : AppColors.neutral600,
                ),
              ),
            ],
          ),
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
