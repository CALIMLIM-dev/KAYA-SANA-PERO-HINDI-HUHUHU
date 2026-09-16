import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';
import '../../../data/services/api_client.dart';
import '../../../core/navigation/app_router.dart';

/*
    The job a conversation is about, pinned above the messages.

    It used to be a title with an arrow that opened to reveal one button.
    It is now the job the way the rest of the app draws a job: the icon
    tile, the title, the pay, the dates and the place on one line, and the
    status of the hire as a pill. Tapping anywhere opens the job. The
    title comes with the conversation so it draws at once; the rest is
    fetched and fills in.
*/
class ChatJobStrip extends StatefulWidget {
  final int jobId;
  final String title;
  final String? status;

  const ChatJobStrip({
    super.key,
    required this.jobId,
    required this.title,
    this.status,
  });

  @override
  State<ChatJobStrip> createState() => _ChatJobStripState();
}

class _ChatJobStripState extends State<ChatJobStrip> {
  Job? _job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().get('/jobs/${widget.jobId}');
      final data = res.data['data'];
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _job = Job.fromApi(data));
      }
    } catch (_) {
      // The title is already on screen. The detail line stays empty.
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final status = job?.status ?? widget.status;
    final detail = _detail(job);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => AppRouter.push(context, '/job-details',
            arguments: {'jobId': widget.jobId}),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.neutral200)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon(job?.category), color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job?.title ?? widget.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                _pill(status),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }

  /// Pay, dates and place, whichever the job has, on one line.
  String _detail(Job? job) {
    if (job == null) return '';
    final parts = <String>[];

    final min = job.salaryMin;
    final max = job.salaryMax;
    if (min != null && max != null && max != min) {
      parts.add('₱${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}/${job.salaryPeriod}');
    } else if (min != null || max != null) {
      parts.add('₱${(min ?? max)!.toStringAsFixed(0)}/${job.salaryPeriod}');
    }

    if (job.scheduleLabel != null) parts.add(job.scheduleLabel!);
    if (job.location != null && job.location!.isNotEmpty) parts.add(job.location!);

    return parts.join('  ·  ');
  }

  Widget _pill(String status) {
    final (label, color) = switch (status) {
      'in_progress' => ('In progress', AppColors.info),
      'completed' => ('Completed', AppColors.success),
      'closed' || 'expired' => ('Closed', AppColors.neutral600),
      _ => ('Open', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color, height: 1.2),
      ),
    );
  }

  IconData _icon(String? category) {
    switch (category?.toLowerCase()) {
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
}
