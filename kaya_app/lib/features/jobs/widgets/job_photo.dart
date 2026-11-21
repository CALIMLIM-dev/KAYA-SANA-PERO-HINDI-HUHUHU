import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading.dart';
import '../../../data/models/job_model.dart';

/// The top of a job card: the employer's own photo of the work, with the
/// URGENT tag, how many photos there are, and an optional save button.
/// A post from before photos were required shows its trade instead.
///
/// Fills whatever box it is given: the Search card sets 16:10, the home
/// carousel a fixed height. One widget so the two cards cannot drift.
class JobPhoto extends StatelessWidget {
  const JobPhoto({super.key, required this.job, this.onToggleSave, this.compact = false});

  final Job job;
  final VoidCallback? onToggleSave;

  /// Smaller tags and icon, for the home carousel's narrow cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final photos = job.photoUrls;
    // Decoded at the width it is drawn, not the 1200 it went up at: a list
    // of full-size bitmaps is what makes a feed stutter.
    final decodeWidth = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          _noPhoto()
        else
          CachedNetworkImage(
            imageUrl: photos.first,
            fit: BoxFit.cover,
            memCacheWidth: decodeWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const ImageLoading(),
            errorWidget: (_, _, _) => _noPhoto(),
          ),

        if (job.isBoosted)
          Positioned(
            top: compact ? 8 : 10,
            left: compact ? 8 : 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
              decoration: BoxDecoration(
                color: Color.alphaBlend(AppColors.accent.withValues(alpha: 0.25), Colors.white),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'URGENT',
                style: TextStyle(
                  fontSize: compact ? 9 : 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8A6D00),
                  height: 1.2,
                ),
              ),
            ),
          ),

        if (photos.length > 1)
          Positioned(
            left: compact ? 8 : 10,
            bottom: compact ? 8 : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${photos.length}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        if (onToggleSave != null)
          Positioned(
            top: 4,
            right: 4,
            // 48dp to tap, a 34dp white disc to see, so it reads on any photo.
            child: IconButton(
              onPressed: onToggleSave,
              tooltip: job.isSaved ? 'Unsave' : 'Save',
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: job.isSaved ? AppColors.primary : AppColors.neutral700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A post from before photos were required: its trade, not a stand-in photo.
  Widget _noPhoto() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(categoryIcon(job.category), size: compact ? 30 : 40, color: AppColors.primary.withValues(alpha: 0.45)),
          if ((job.category ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                job.category!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The trade's icon, matched loosely so "Plumbing Services" still finds it.
  static IconData categoryIcon(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('plumb')) return Icons.plumbing;
    if (c.contains('electric')) return Icons.electrical_services;
    if (c.contains('paint')) return Icons.format_paint;
    if (c.contains('carpent') || c.contains('construct') || c.contains('mason')) return Icons.construction;
    if (c.contains('clean')) return Icons.cleaning_services;
    if (c.contains('garden') || c.contains('landscap')) return Icons.grass;
    if (c.contains('aircon') || c.contains('hvac')) return Icons.ac_unit;
    if (c.contains('auto') || c.contains('mechanic')) return Icons.car_repair;
    return Icons.work_outline;
  }
}
