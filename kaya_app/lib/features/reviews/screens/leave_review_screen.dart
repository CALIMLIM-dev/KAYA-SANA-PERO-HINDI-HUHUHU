import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/review_provider.dart';
import '../../../core/widgets/app_toast.dart';

/// Leave Review Screen — post-job completion, either party leaves a review
/// Arguments: { revieweeName, revieweeRole ('worker' | 'employer'), jobTitle }
class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  // Tag chips — quick descriptors
  final List<String> _workerTags = [
    'On time', 'Professional', 'Quality work', 'Good communication',
    'Clean workspace', 'Fair pricing', 'Would hire again',
  ];
  final List<String> _employerTags = [
    'Clear instructions', 'Paid on time', 'Respectful', 'Responsive',
    'Fair requirements', 'Good environment', 'Would work again',
  ];
  final Set<String> _selectedTags = {};

  bool get _canSubmit => _rating > 0 && _commentController.text.trim().length >= 10;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final revieweeName = args?['revieweeName'] as String? ?? 'Juan Dela Cruz';
    final revieweeRole = args?['revieweeRole'] as String? ?? 'worker';
    final jobTitle     = args?['jobTitle']     as String? ?? 'Emergency Pipe Repair';
    final isWorker     = revieweeRole == 'worker';
    final tags         = isWorker ? _workerTags : _employerTags;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Leave a Review',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Who you're reviewing ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            revieweeName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(revieweeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral900,
                                  )),
                              const SizedBox(height: 3),
                              Text(
                                isWorker ? 'Worker' : 'Employer',
                                style: const TextStyle(
                                    fontSize: 13.5, color: AppColors.neutral500),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.work_outline,
                                      size: 13, color: AppColors.neutral400),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      jobTitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.neutral500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Star rating ──
                  const Text('Your Rating',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900)),
                  const SizedBox(height: 4),
                  const Text('Tap to rate',
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.neutral500)),
                  const SizedBox(height: 12),

                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 44,
                            color: filled ? Colors.amber : AppColors.neutral300,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_rating > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      _ratingLabel(_rating),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _rating >= 4
                            ? AppColors.success
                            : _rating == 3
                                ? AppColors.warning
                                : AppColors.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Quick tags ──
                  const Text('What stood out?',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900)),
                  const SizedBox(height: 4),
                  const Text('Select all that apply',
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.neutral500)),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          selected
                              ? _selectedTags.remove(tag)
                              : _selectedTags.add(tag);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.neutral300,
                            ),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.neutral700,
                              )),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Written review ──
                  const Text('Write a Review',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900)),
                  const SizedBox(height: 4),
                  const Text('Share your experience (min 10 characters)',
                      style: TextStyle(
                          fontSize: 13.5, color: AppColors.neutral500)),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isWorker
                          ? 'How was the quality of work? Was the worker professional and on time?'
                          : 'Was the employer clear about the job? Did they pay on time?',
                      hintStyle: const TextStyle(
                          color: AppColors.neutral400, fontSize: 13.5),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.neutral300)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.neutral300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Submit button ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_isSubmitting
                      ? () => _submitReview(
                            revieweeName,
                            revieweeId: args?['revieweeId'] as int?,
                            jobId: args?['jobId'] as int?,
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    disabledForegroundColor: AppColors.neutral500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Review',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent';
      default: return '';
    }
  }

  Future<void> _submitReview(
    String revieweeName, {
    required int? revieweeId,
    required int? jobId,
  }) async {
    // Previously this faked an 800ms delay and reported the review as submitted
    // without sending anything.
    if (revieweeId == null || jobId == null) {
      AppToast.error(context, 'Cannot submit: missing job or person details.');
      return;
    }

    setState(() => _isSubmitting = true);

    final reviews = context.read<ReviewProvider>();
    final success = await reviews.submitReview(
      revieweeId: revieweeId,
      jobId: jobId,
      rating: _rating,
      comment: _commentController.text,
      // These were collected into _selectedTags and then left behind — the
      // chips responded to every tap and changed nothing.
      tags: _selectedTags.toList(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    AppToast.info(context, success
            ? 'Review for $revieweeName submitted'
            : reviews.errorMessage ?? 'Could not submit review');

    if (success) Navigator.pop(context, true);
  }
}
