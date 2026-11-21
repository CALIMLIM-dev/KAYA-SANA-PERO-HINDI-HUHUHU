import 'package:flutter/material.dart';
import 'fit_line.dart';
import 'job_photo.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../data/models/job_model.dart';

/// The job card for a full-width vertical list: search results, saved jobs.
///
/// Marketplace order: the employer's own photo of the work fills the top,
/// then the pay, then what the job is and where. A worker scrolling Search
/// judges a job by what it looks like and what it pays before reading a
/// word, so those two come first. Every job posted since photos became
/// required has one; an older post shows its trade instead.
class JobListCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onToggleSave;

  const JobListCard({
    super.key,
    required this.job,
    this.onTap,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    // The shadow sits outside the clip, so the photo's corners can be
    // rounded without cutting the shadow off.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(aspectRatio: 16 / 10, child: JobPhoto(job: job, onToggleSave: onToggleSave)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: _details(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── details ──────────────────────────────────────────────────────────────

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _salary(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          job.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                job.company.isEmpty ? 'Private Employer' : job.company,
                style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            VerificationChip(state: job.employerVerification, size: 10),
          ],
        ),

        if (job.fitLine != null) ...[
          const SizedBox(height: 8),
          FitLine(text: job.fitLine!, strong: job.matchTier == 2),
        ],

        if (job.location != null || job.distance != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.neutral500, size: 14),
              const SizedBox(width: 5),
              // The address truncates; the distance never does.
              Expanded(
                child: Text(
                  job.location ?? '',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (distanceText(job.distanceLabel, job.distance) != null) ...[
                const SizedBox(width: 8),
                Text(
                  distanceText(job.distanceLabel, job.distance)!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral700,
                  ),
                ),
              ],
            ],
          ),
        ],

        if (job.scheduleLabel != null || job.startsLabel != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.event, color: AppColors.neutral500, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  [job.scheduleLabel, job.startsLabel].whereType<String>().join('  ·  '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        if (job.requiredSkills.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.handyman_outlined, color: AppColors.neutral500, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  job.requiredSkills.join(', '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.neutral200),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Text(
                _footer(),
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _statusColor()),
                backgroundColor: job.applicationStatus != null ? _statusColor().withValues(alpha: 0.1) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _statusText(),
                style: TextStyle(
                  color: _statusColor(),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 4000 -> "4,000".
  static String _peso(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String _salary() {
    final min = job.salaryMin;
    final max = job.salaryMax;
    if (min != null && max != null && max != min) {
      return '₱${_peso(min)}-${_peso(max)}${job.payUnit}';
    }
    final one = min ?? max;
    if (one != null) return '₱${_peso(one)}${job.payUnit}';
    return 'Payment terms: to be discussed';
  }

  String _footer() {
    final n = job.applicantCount;
    final parts = ['$n applicant${n != 1 ? 's' : ''}'];
    final ago = _timeAgo();
    if (ago.isNotEmpty) parts.add(ago);
    return parts.join('  ·  ');
  }

  String _timeAgo() {
    final at = job.postedAt;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  Color _statusColor() {
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

  String _statusText() {
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
