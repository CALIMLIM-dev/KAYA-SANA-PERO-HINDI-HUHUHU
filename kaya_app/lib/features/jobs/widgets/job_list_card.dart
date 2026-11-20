import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'fit_line.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading.dart';
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
              _photo(context),
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

  // ─── photo ────────────────────────────────────────────────────────────────

  Widget _photo(BuildContext context) {
    final photos = job.photoUrls;
    // Decoded at the width it is drawn, not the 1200 it went up at: a list
    // of full-size bitmaps is what makes a feed stutter.
    final decodeWidth = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
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
              top: 10,
              left: 10,
              child: _pill('URGENT', const Color(0xFF8A6D00), Color.alphaBlend(AppColors.accent.withValues(alpha: 0.25), Colors.white)),
            ),

          if (photos.length > 1)
            Positioned(
              left: 10,
              bottom: 10,
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
      ),
    );
  }

  /// A post from before photos were required: its trade, not a stand-in photo.
  Widget _noPhoto() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_categoryIcon(), size: 40, color: AppColors.primary.withValues(alpha: 0.45)),
          if ((job.category ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                job.category!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral600),
              ),
            ),
          ],
        ],
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
    final c = (job.category ?? '').toLowerCase();
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
