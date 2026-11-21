import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../data/models/job_model.dart';
import 'job_photo.dart';

/// The job card for the home carousels.
///
/// The same order as the Search card (JobListCard): the employer's photo of
/// the work on top, then the pay, then what the job is and where. Drawn at a
/// fixed height in a row that scrolls sideways, so every line is one line and
/// the bottom row sits on the floor.
class CompactJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onContact;

  const CompactJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onContact,
  });

  /// The photo band on top. Fixed, not scaled with text: the carousels add
  /// it to their text-scaled height, so a card never clips its own lines.
  static const double photoHeight = 104;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    // The shadow sits outside the clip, so the photo can have rounded top
    // corners without the shadow being cut off.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(builder: (context, constraints) {
            final details = Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pay first, as on the Search card: the number the decision turns on.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatSalary(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            height: 1.2,
                          ),
                        ),
                      ),
                      // The short form of the fit line: "1 of 2 skills".
                      if (job.matchTier != null && job.requiredCount > 0)
                        Text(
                          '${job.matchedCount} of ${job.requiredCount} skills',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: job.matchedCount > 0 ? AppColors.primary : AppColors.neutral500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                  ),
                  // The hirer's verification, beside the hirer.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          job.company.isEmpty ? 'Private Employer' : job.company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small?.copyWith(color: AppColors.neutral600, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 4),
                      VerificationChip(state: job.employerVerification, size: 9.5),
                    ],
                  ),
                  // The address truncates; the distance never does.
                  if (job.location != null || job.distance != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.neutral500, size: 11),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            job.location ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small?.copyWith(color: AppColors.neutral500, fontSize: 10.5),
                          ),
                        ),
                        if (distanceText(job.distanceLabel, job.distance) != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            distanceText(job.distanceLabel, job.distance)!,
                            style: small?.copyWith(
                              color: AppColors.neutral600,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (job.scheduleLabel != null || job.startsLabel != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.event, color: AppColors.neutral500, size: 11),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            [job.scheduleLabel, job.startsLabel].whereType<String>().join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small?.copyWith(
                              color: AppColors.neutral600,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // A carousel fixes the height, so the bottom row sits on the
                  // floor. In an unbounded list a Spacer would be an error.
                  if (constraints.hasBoundedHeight) const Spacer() else const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            '${job.applicantCount} applicant${job.applicantCount != 1 ? 's' : ''}',
                            if (job.postedAt != null) _getTimeAgo(),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small?.copyWith(
                            color: AppColors.neutral600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: onContact ?? onTap,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _getApplicationButtonColor()),
                          backgroundColor: _getApplicationStatus() != null
                              ? _getApplicationButtonColor().withValues(alpha: 0.1)
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _getApplicationButtonText(),
                          style: TextStyle(
                            color: _getApplicationButtonColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: photoHeight, child: JobPhoto(job: job, compact: true)),
                if (constraints.hasBoundedHeight) Expanded(child: details) else details,
              ],
            );
          }),
        ),
      ),
    );
  }

  /// 4000 -> "4,000".
  static String _peso(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String _formatSalary() {
    final min = job.salaryMin;
    final max = job.salaryMax;
    if (min != null && max != null && max != min) return '₱${_peso(min)}-${_peso(max)}${job.payUnit}';
    final one = min ?? max;
    if (one != null) return '₱${_peso(one)}${job.payUnit}';
    return 'To be discussed';
  }

  String _getTimeAgo() {
    if (job.postedAt == null) return '';
    final difference = DateTime.now().difference(job.postedAt!);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  ApplicationStatus? _getApplicationStatus() => job.applicationStatus;

  Color _getApplicationButtonColor() {
    switch (job.applicationStatus) {
      case ApplicationStatus.pending:
        return AppColors.warning;
      case ApplicationStatus.accepted:
        return AppColors.success;
      case ApplicationStatus.rejected:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  /// What the button does: it opens the job. Messaging is only possible
  /// once an application is accepted, so it never says "Contact".
  String _getApplicationButtonText() {
    switch (job.applicationStatus) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.rejected:
        return 'Rejected';
      default:
        return 'View Job';
    }
  }
}
