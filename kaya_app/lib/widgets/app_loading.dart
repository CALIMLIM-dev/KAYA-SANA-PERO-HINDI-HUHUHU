import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Loading skeleton that matches the shape of content it replaces
class AppLoadingSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double? borderRadius;

  const AppLoadingSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.borderColor,
      highlightColor: AppTheme.surfaceColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.borderColor,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppTheme.radiusMedium,
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton for list items
class AppListItemSkeleton extends StatelessWidget {
  const AppListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          const AppLoadingSkeleton(
            width: 60,
            height: 60,
            borderRadius: 30,
          ),
          AppSpacing.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLoadingSkeleton(width: double.infinity, height: 16),
                AppSpacing.h8,
                const AppLoadingSkeleton(width: 150, height: 14),
                AppSpacing.h8,
                const AppLoadingSkeleton(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for cards
class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLoadingSkeleton(width: double.infinity, height: 20),
            AppSpacing.h12,
            const AppLoadingSkeleton(width: double.infinity, height: 16),
            AppSpacing.h8,
            const AppLoadingSkeleton(width: 200, height: 14),
            AppSpacing.h16,
            Row(
              children: [
                const Expanded(
                  child: AppLoadingSkeleton(width: double.infinity, height: 40),
                ),
                AppSpacing.w12,
                const Expanded(
                  child: AppLoadingSkeleton(width: double.infinity, height: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
