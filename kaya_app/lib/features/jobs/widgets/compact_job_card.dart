import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/job_model.dart';

/// Compact Job Card matching Worker Card style
/// Vertical layout with fixed dimensions for horizontal scrolling
class CompactJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onContact;
  final List<String> workerSkills;

  const CompactJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onContact,
    this.workerSkills = const [],
  });

  // ─── match calculation ────────────────────────────────────────────────────
  //
  // Prefers the server's match_score (JobMatchService — category-first, so a
  // same-trade worker with no exact skill overlap still scores well and stays
  // visible). The client-side skill-overlap calculation below is only a
  // fallback for a Job that was not loaded from GET /jobs (e.g. still mocked
  // in a screen this card hasn't been wired into yet), where matchScore is
  // always null and skills-only was the entire signal — it would have hidden
  // a valid same-category worker with zero exact skill matches.
  bool get _showMatch =>
      job.matchScore != null ||
      (workerSkills.isNotEmpty && job.requiredSkills.isNotEmpty);

  int get _matchPercent {
    if (job.matchScore != null) return job.matchScore!;
    if (workerSkills.isEmpty || job.requiredSkills.isEmpty) return 0;

    final wLower = workerSkills.map((s) => s.toLowerCase()).toSet();
    final matched = job.requiredSkills
        .where((s) => wLower.contains(s.toLowerCase()))
        .length;
    return ((matched / job.requiredSkills.length) * 100).round();
  }

  Color get _matchColor {
    final p = _matchPercent;
    if (p >= 80) return AppColors.success;
    if (p >= 50) return AppColors.warning;
    return AppColors.neutral600;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Job Header Row - Compact
            SizedBox(
              height: 45,
              child: Row(
                children: [
                  // Company/Category Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // Job Title and Company
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (job.requiresVerification) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified, color: AppColors.verified, size: 12),
                            ],
                          ],
                        ),
                        Text(
                          job.company,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  
                  // Urgent badge.
                  //
                  // This was a 6px dot stacked above the word URGENT in a
                  // Column, which rendered as a loose dot floating beside the
                  // job title with the label crushed underneath it — it read as
                  // a rendering fault rather than a badge. A pill, matching the
                  // match-percentage chip on the row below, says the same thing
                  // in one line and sits in the space that is actually there.
                  if (job.isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A6D00),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Salary Row + Match % - Compact
            SizedBox(
              height: 16,
              child: Row(
                children: [
                  const Icon(Icons.payments, color: AppColors.success, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    _formatSalary(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  if (_showMatch)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _matchColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_matchPercent%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _matchColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Location and Distance - Compact
            if (job.location != null || job.distance != null) ...[
              const SizedBox(height: 2),
              SizedBox(
                height: 14,
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.neutral500, size: 10),
                    const SizedBox(width: 3),
                    /*
                        Location and distance as two elements, not one string.

                        They were joined into "Brgy. Nancayasan, Urdaneta City,
                        Pangasinan • 3.4 km" and ellipsized as a whole, so on
                        any job with a full barangay-level address the distance
                        — the last thing in the string — was always the part
                        that got cut. On a list whose entire premise is
                        "nearest first", that is the one number worth keeping.

                        The address truncates; the distance never does.
                    */
                    Expanded(
                      child: Text(
                        job.location ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (job.distance != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatDistance(job.distance!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral600,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            /*
                When the job actually happens.

                Job.scheduleLabel has existed since scheduling landed, with a
                comment saying the card, the details page and the applications
                list should all read from it so they cannot describe the same
                dates differently — and then no card ever rendered it. A worker
                deciding whether to tap could not see whether the job was next
                week or today without opening it.

                It goes in the gap the Spacer was already holding open, so the
                card does not grow.
            */
            if (job.scheduleLabel != null) ...[
              const SizedBox(height: 2),
              SizedBox(
                height: 14,
                child: Row(
                  children: [
                    const Icon(Icons.event,
                        color: AppColors.neutral500, size: 10),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        job.scheduleLabel!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral600,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),
            
            // Bottom Row: Applicants and Action Button
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job.applicantCount} applicant${job.applicantCount != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (job.postedAt != null)
                          Text(
                            _getTimeAgo(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral500,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  
                  // Action Button
                  OutlinedButton(
                    onPressed: onContact,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _getApplicationButtonColor(),
                      ),
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
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (job.category?.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'painting':
        return Icons.format_paint;
      case 'carpentry':
        return Icons.construction;
      default:
        return Icons.work;
    }
  }

  String _formatSalary() {
    if (job.salaryMin != null && job.salaryMax != null) {
      return '₱${job.salaryMin!.toStringAsFixed(0)}-${job.salaryMax!.toStringAsFixed(0)}/${job.salaryPeriod}';
    } else if (job.salaryMin != null) {
      return '₱${job.salaryMin!.toStringAsFixed(0)}/${job.salaryPeriod}';
    } else if (job.salaryMax != null) {
      return '₱${job.salaryMax!.toStringAsFixed(0)}/${job.salaryPeriod}';
    }
    return 'Negotiable';
  }

  String _getTimeAgo() {
    if (job.postedAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(job.postedAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  ApplicationStatus? _getApplicationStatus() {
    return job.applicationStatus;
  }

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

  /// What the button does, not what we wish it did.
  ///
  /// This said "Contact", which promises a message to the employer. It opens
  /// the job. Messaging is not possible before applying anyway — a conversation
  /// only exists once an application is accepted, which is the rule that keeps
  /// the inbox from becoming a cold-contact channel. So the label was offering
  /// something the app deliberately does not do, on every job card on the home
  /// screen.
  String _getApplicationButtonText() {
    switch (job.applicationStatus) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.rejected:
        return 'Rejected';
      default:
        return 'View job';
    }
  }
}

