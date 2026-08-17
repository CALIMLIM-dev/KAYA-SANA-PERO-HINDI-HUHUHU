import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/worker_profile_model.dart';

/// Compact Worker Card for horizontal scrolling  
/// Dimensions: ~280w x 140h pixels
class CompactWorkerCard extends StatelessWidget {
  final WorkerProfile worker;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;

  const CompactWorkerCard({
    super.key,
    required this.worker,
    this.onTap,
    this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10), // Reduced padding to prevent overflow
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
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            // Profile Header Row - More compact
            SizedBox(
              height: 45, // Fixed height to control layout
              child: Row(
                children: [
                  // Avatar - smaller
                  CircleAvatar(
                    radius: 18, // Reduced from 20
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: worker.profileImageUrl != null 
                        ? NetworkImage(worker.profileImageUrl!) 
                        : null,
                    child: worker.profileImageUrl == null
                        ? Text(
                            worker.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14, // Reduced font size
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  
                  // Name and Skill Column - more compact
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                worker.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (worker.isVerified) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified, color: AppColors.verified, size: 12),
                            ],
                          ],
                        ),
                        Text(
                          worker.primarySkill,
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
                  
                  // Availability Indicator - compact
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Color(worker.availabilityColorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        worker.isAvailable ? 'Available' : 'Busy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Color(worker.availabilityColorValue),
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
            
            // Rating and Reviews Row - compact
            SizedBox(
              height: 16,
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    worker.ratingDisplay,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Location and Distance - compact
            if (worker.location != null || worker.distance != null) ...[
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
            
            // Bottom Row: Rate/Experience and Invite Button - Fixed height
            SizedBox(
              height: 32, // Fixed height to prevent overflow
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (worker.hourlyRate != null)
                          Text(
                            '₱${worker.hourlyRate!.toStringAsFixed(0)}/hr',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          worker.experienceDisplay,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  
                  // Invite Button - smaller
                  OutlinedButton(
                    onPressed: worker.isAvailable ? onInvite : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: worker.isAvailable ? AppColors.primary : AppColors.neutral400,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      worker.isAvailable ? 'Invite' : 'Busy',
                      style: TextStyle(
                        color: worker.isAvailable ? AppColors.primary : AppColors.neutral400,
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

  String _getLocationText() {
    final parts = <String>[];
    if (worker.location != null) {
      parts.add(worker.location!);
    }
    if (worker.distance != null) {
      parts.add(formatDistance(worker.distance!));
    }
    return parts.join(' • ');
  }
}