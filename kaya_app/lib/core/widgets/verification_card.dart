import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    One verification row, used by both profiles.

    There were two of these, one per profile screen, and they had already
    drifted: the worker's read the real status from the provider and drew
    pending and rejected states, while the employer's was called with
    `isVerified: false` hard-coded at every call site - so an employer who had
    been approved still saw "Upload DTI, SEC, or Mayor's permit" with a chevron,
    as though nothing had been submitted.

    Styled as a section rather than a floating card. The rest of both profiles
    is white on a neutral200 hairline at 12px radius, and the old employer
    version used Material elevation, which is why that tab looked like it came
    from a different app.
*/
class VerificationCard extends StatelessWidget {
  const VerificationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.status,
  });

  final String title;

  /// What to upload. Shown only while there is nothing to show instead.
  final String subtitle;

  final IconData icon;

  /// Document type, passed to the verification screen.
  final String type;

  /// 'verified' | 'pending' | 'rejected' | anything else for not submitted.
  final String status;

  bool get _isVerified => status == 'verified';
  bool get _isPending => status == 'pending';
  bool get _isRejected => status == 'rejected';

  @override
  Widget build(BuildContext context) {
    final (Color tone, IconData mark, String? label) = switch (status) {
      'verified' => (AppColors.success, Icons.check_circle, 'Verified'),
      'pending' => (AppColors.warning, Icons.hourglass_top, 'Under review'),
      'rejected' => (AppColors.error, Icons.error_outline, 'Rejected'),
      _ => (AppColors.neutral600, icon, null),
    };

    /*
        An approved document is not a button.

        Tapping it opened the upload screen again, which reads as an invitation
        to replace something that is finished. Pending and rejected both stay
        tappable - one to check, one to fix.
    */
    final tappable = !_isVerified;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable
              ? () => Navigator.pushNamed(
                    context,
                    '/verification',
                    arguments: {
                      'type': type,
                      'title': title,
                      'subtitle': subtitle,
                    },
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(mark, color: tone, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // What to do next, or what happened. The upload hint
                        // is useless once something has been submitted.
                        _isPending
                            ? 'We are checking your document'
                            : _isRejected
                                ? 'Not accepted — tap to send another'
                                : _isVerified
                                    ? 'Approved'
                                    : subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (label != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
