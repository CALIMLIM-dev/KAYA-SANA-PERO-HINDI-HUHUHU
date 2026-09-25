import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/profile_avatar.dart';

/*
    One notice on the board: who, what, where, and how long it has left.

    The whole card opens the post. Nothing else on it is tappable, so a
    thumb landing anywhere does the one thing a person tapping a notice
    wants, which is to read it.
*/
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({super.key, required this.post, required this.onTap});

  final Map<String, dynamic> post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final poster = (post['poster'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isBusiness = post['type'] == 'business';
    final photo = post['photo_url'] as String?;
    final daysLeft = (post['days_left'] as num?)?.toInt();
    final where = (post['location'] ?? '').toString();
    final category = (post['category'] ?? '').toString();
    final status = (post['status'] ?? 'live').toString();
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
                          if (poster['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: AppColors.primary),
                          ],
                        ],
                      ),
                      Text(
                        [
                          isBusiness ? 'Hiring' : 'Available',
                          if (category.isNotEmpty) category,
                          if (where.isNotEmpty) where,
                        ].join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(
                  // A post waits to be read before it reaches the board, so
                  // its own author needs to be told that rather than shown a
                  // blank where a countdown goes.
                  text: status == 'pending'
                      ? 'Waiting for review'
                      : status == 'rejected'
                          ? 'Not approved'
                          : status != 'live'
                              ? (status == 'removed' ? 'Removed' : 'Ended')
                              : daysLeft == null
                                  ? ''
                                  : daysLeft <= 0
                                      ? 'Last day'
                                      : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                  tint: status == 'pending'
                      ? AppColors.warning
                      : status == 'rejected'
                          ? AppColors.error
                          : status != 'live'
                              ? AppColors.neutral500
                              : (isBusiness ? AppColors.primary : AppColors.success),
                ),
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
