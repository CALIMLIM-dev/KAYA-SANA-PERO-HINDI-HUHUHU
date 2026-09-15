import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/job_model.dart';

/// The job card for a full-width vertical list: search results, saved jobs.
///
/// Same family as the home carousel's CompactJobCard, which is drawn at
/// 168px tall in a row that scrolls sideways and has to fit in that. This
/// one has the whole width of the screen, so the title runs to two lines,
/// the type is a size a list is read at, and the bookmark sits where the
/// thumb reaches it. The two share their icons, colours and the order of
/// lines so a job looks like the same job from either tab.
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

  Color get _matchColor {
    final p = job.matchScore ?? 0;
    if (p >= 80) return AppColors.success;
    if (p >= 50) return AppColors.warning;
    return AppColors.neutral600;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
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
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _categoryIcon(),
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job.company.isEmpty
                                    ? 'Private employer'
                                    : job.company,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.neutral600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (job.requiresVerification) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.verified, size: 14),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onToggleSave != null)
                    IconButton(
                      onPressed: onToggleSave,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 36, height: 36),
                      visualDensity: VisualDensity.compact,
                      tooltip: job.isSaved ? 'Unsave' : 'Save',
                      icon: Icon(
                        job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 22,
                        color: job.isSaved
                            ? AppColors.primary
                            : AppColors.neutral500,
                      ),
                    ),
                ],
              ),

              // Urgent and match, as pills, only when there is something to
              // say. An empty row would leave a gap under every plain job.
              if (job.isUrgent || job.matchScore != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (job.isUrgent)
                      _pill('URGENT', const Color(0xFF8A6D00),
                          AppColors.accent.withValues(alpha: 0.16)),
                    if (job.matchScore != null)
                      _pill('${job.matchScore}% match', _matchColor,
                          _matchColor.withValues(alpha: 0.12)),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(Icons.payments,
                      color: AppColors.success, size: 15),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _salary(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (job.location != null || job.distance != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.neutral500, size: 14),
                    const SizedBox(width: 5),
                    // The address truncates; the distance never does.
                    Expanded(
                      child: Text(
                        job.location ?? '',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.neutral600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (job.distance != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatDistance(job.distance!),
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

              if (job.scheduleLabel != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.event,
                        color: AppColors.neutral500, size: 14),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        job.scheduleLabel!,
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
                    const Icon(Icons.handyman_outlined,
                        color: AppColors.neutral500, size: 14),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        job.requiredSkills.join(', '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.neutral600,
                        ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _statusColor()),
                        backgroundColor: job.applicationStatus != null
                            ? _statusColor().withValues(alpha: 0.1)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }

  IconData _categoryIcon() {
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

  String _salary() {
    final min = job.salaryMin;
    final max = job.salaryMax;
    if (min != null && max != null && max != min) {
      return '₱${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}/${job.salaryPeriod}';
    }
    final one = min ?? max;
    if (one != null) return '₱${one.toStringAsFixed(0)}/${job.salaryPeriod}';
    return 'Negotiable';
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
        return 'View job';
    }
  }
}
