import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';

/// Compact Job Card matching Worker Card style
/// Vertical layout with fixed dimensions for horizontal scrolling
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
                                  fontSize: 13,
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
                  
                  // Urgent Badge
                  if (job.isUrgent)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'URGENT',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Salary Row - Compact
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
                    Expanded(
                      child: Text(
                        _getLocationText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                          fontSize: 10,
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

  String _getLocationText() {
    final parts = <String>[];
    if (job.location != null) {
      parts.add(job.location!);
    }
    if (job.distance != null) {
      parts.add('${job.distance!.toStringAsFixed(1)}km away');
    }
    return parts.join(' • ');
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

  String _getApplicationButtonText() {
    switch (job.applicationStatus) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.rejected:
        return 'Rejected';
      default:
        return 'Contact';
    }
  }
}

