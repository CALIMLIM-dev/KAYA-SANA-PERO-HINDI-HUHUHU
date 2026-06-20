import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../theme/app_theme.dart';

/// Display rating with stars (read-only)
class AppRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;

  const AppRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemBuilder: (context, index) => const Icon(
            Icons.star_rounded,
            color: AppTheme.warningColor,
          ),
          itemCount: 5,
          itemSize: size,
          direction: Axis.horizontal,
        ),
        if (showValue) ...[
          AppSpacing.w4,
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Rating input with stars (interactive)
class AppRatingInput extends StatelessWidget {
  final double initialRating;
  final ValueChanged<double> onRatingUpdate;
  final double size;

  const AppRatingInput({
    super.key,
    required this.initialRating,
    required this.onRatingUpdate,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: initialRating,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: size,
      itemBuilder: (context, _) => const Icon(
        Icons.star_rounded,
        color: AppTheme.warningColor,
      ),
      onRatingUpdate: onRatingUpdate,
    );
  }
}
