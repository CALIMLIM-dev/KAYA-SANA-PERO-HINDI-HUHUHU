import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/verification_badge_widget.dart';

class ApplicationCard extends StatelessWidget {
  final String jobTitle;
  final String company;
  final String location;
  final String appliedDate;
  final String? acceptedDate;
  final String? rejectedDate;
  final String? completedDate;
  final String status; // pending, accepted, rejected, completed
  final String salary;
  final bool isVerified;
  final bool hasReview;
  final VoidCallback onTap;
  final VoidCallback? onWithdraw;
  final VoidCallback? onMessage;
  final VoidCallback? onReview;

  const ApplicationCard({
    super.key,
    required this.jobTitle,
    required this.company,
    required this.location,
    required this.appliedDate,
    this.acceptedDate,
    this.rejectedDate,
    this.completedDate,
    required this.status,
    required this.salary,
    required this.isVerified,
    this.hasReview = false,
    required this.onTap,
    this.onWithdraw,
    this.onMessage,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor().withAlpha(51),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Capped for the reason described on the job card:
                          // a bare Text in a Row takes the width it wants.
                          Expanded(
                            child: Text(
                              company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.neutral700,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const VerificationBadgeWidget(isVerified: true, size: 14),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: AppColors.neutral600),
                const SizedBox(width: 4),
                // The address is the longest thing on this row and the pay
                // beside it must stay visible, so the address is what yields.
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  salary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Applied $appliedDate',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            if (acceptedDate != null) ...[
              Text(
                'Accepted $acceptedDate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
            if (rejectedDate != null) ...[
              Text(
                'Rejected $rejectedDate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            if (completedDate != null) ...[
              Text(
                'Completed $completedDate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.info,
                ),
              ),
            ],
            if (_shouldShowActions()) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  bool _shouldShowActions() {
    return status == 'pending' || status == 'accepted' || (status == 'completed' && !hasReview);
  }

  Widget _buildActions(BuildContext context) {
    if (status == 'pending' && onWithdraw != null) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onWithdraw,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
          ),
          child: const Text('Withdraw'),
        ),
      );
    }

    if (status == 'accepted' && onMessage != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.message, size: 18),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (status == 'completed' && !hasReview && onReview != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.star_outline, size: 18),
            label: const Text('Leave Review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor() {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'withdrawn':
        return AppColors.neutral400;
      default:
        return AppColors.neutral400;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getColor().withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor().withAlpha(51)),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getColor(),
        ),
      ),
    );
  }

  String _getLabel() {
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _getColor() {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'withdrawn':
        return AppColors.neutral400;
      default:
        return AppColors.neutral400;
    }
  }
}
