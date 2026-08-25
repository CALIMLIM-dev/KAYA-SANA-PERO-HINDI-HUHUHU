import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// How complete a profile is, and the one thing to do next.
///
/// The ring is the point. A percentage in text is a fact; a ring that is
/// visibly short of closing is an itch — and the whole reason this pattern
/// works on hiring apps is that people finish profiles to close the circle.
///
/// One prompt, never a checklist. The server already sorts what is missing by
/// how much it is worth, so this shows the heaviest item and nothing else: a
/// list of nine outstanding tasks reads as a chore and gets ignored, while one
/// clear next step gets done.
class ProfileCompletenessHeader extends StatelessWidget {
  const ProfileCompletenessHeader({
    super.key,
    required this.percent,
    this.next,
    this.onTap,
  });

  /// 0 to 100, computed server side so every screen shows the same number.
  final int percent;

  /// The single most valuable missing item, or null when nothing is missing.
  final String? next;

  final VoidCallback? onTap;

  bool get _isComplete => percent >= 100;

  @override
  Widget build(BuildContext context) {
    final colour = _isComplete ? AppColors.success : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Drawn rather than animated on build: this rebuilds whenever
                // the profile changes, and a ring that restarts its animation
                // every time a field is saved is noise, not feedback.
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: percent / 100,
                    strokeWidth: 5,
                    backgroundColor: AppColors.neutral200,
                    valueColor: AlwaysStoppedAnimation<Color>(colour),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isComplete ? 'Your profile is complete' : 'Complete your profile',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isComplete
                      ? 'Employers can see everything they need.'
                      : (next ?? 'Add a little more to stand out.'),
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
                ),
              ],
            ),
          ),
          if (onTap != null && !_isComplete)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right, color: AppColors.neutral400),
              tooltip: next,
            ),
        ],
      ),
    );
  }
}

/// A ring with no text, for a compact header.
class MiniCompletenessRing extends StatelessWidget {
  const MiniCompletenessRing({super.key, required this.percent, this.size = 34});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: math.min(1, percent / 100),
        strokeWidth: 3,
        backgroundColor: AppColors.neutral200,
        valueColor: AlwaysStoppedAnimation<Color>(
          percent >= 100 ? AppColors.success : AppColors.primary,
        ),
      ),
    );
  }
}
