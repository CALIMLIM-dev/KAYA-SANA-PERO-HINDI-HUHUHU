import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/realtime_refresh.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/job_provider.dart';
import '../widgets/featured_job_card.dart';

/// Jobs the worker saved.
///
/// This screen used to render five hardcoded cards — "Emergency Pipe Repair",
/// "Electrician Needed" and so on — with a refresh that waited a second and did
/// nothing, and a Clear All that showed a success message and deleted nothing.
/// A worker who saved a job never saw it here.
class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen>
    with RealtimeRefresh<SavedJobsScreen> {
  bool _clearing = false;

  // A job can be closed or filled while it sits in someone's saved list.
  @override
  List<String> get refreshOn => const ['job'];

  @override
  void onRealtimeRefresh() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    bindRealtimeRefresh();
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<JobProvider>().fetchSavedJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobs, _) {
        final saved = jobs.savedJobs;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Saved Jobs'),
            actions: [
              // Hidden when there is nothing to clear, rather than offered and
              // then doing nothing.
              if (saved.isNotEmpty)
                TextButton(
                  onPressed: _clearing ? null : _confirmClearAll,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: _clearing ? AppColors.neutral400 : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: _buildBody(jobs, saved),
          ),
        );
      },
    );
  }

  Widget _buildBody(JobProvider jobs, List<Job> saved) {
    if (jobs.isSavedLoading && saved.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (jobs.savedErrorMessage != null && saved.isEmpty) {
      return _message(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your saved jobs',
        body: jobs.savedErrorMessage!,
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }

    if (saved.isEmpty) {
      return _message(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved jobs yet',
        body: 'Tap the bookmark on a job to keep it here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: saved.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _card(saved[index]),
    );
  }

  Widget _card(Job job) {
    return FeaturedJobCard(
      title: job.title,
      company: job.company.isEmpty ? 'Private Employer' : job.company,
      location: job.location ?? 'Location not set',
      // Employer rating is not part of the job payload, so it is left blank
      // rather than invented — same as the search results.
      rating: '',
      reviews: '',
      salary: _formatSalary(job.salaryMin, job.salaryMax),
      category: job.category,
      distance: job.distance == null ? null : formatDistance(job.distance!),
      isUrgent: job.isUrgent,
      requiresVerification: job.requiresVerification,
      requiredSkills: job.requiredSkills,
      matchScore: job.matchScore,
      onTap: () async {
        await Navigator.pushNamed(context, '/job-details',
            arguments: {'jobId': job.id});
        // Unsaving from the details screen must not leave the job sitting here.
        if (mounted) _load();
      },
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    // A ListView so pull-to-refresh still works on an empty screen.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(icon, size: 40, color: AppColors.neutral300),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.neutral500),
        ),
        if (action != null) ...[
          const SizedBox(height: 8),
          Center(child: action),
        ],
      ],
    );
  }

  String _formatSalary(double? min, double? max) {
    if (min == null && max == null) return 'Salary not set';
    if (min != null && max != null && min != max) {
      return '₱${min.toStringAsFixed(0)} – ₱${max.toStringAsFixed(0)}';
    }
    return '₱${(min ?? max)!.toStringAsFixed(0)}';
  }

  Future<void> _confirmClearAll() async {
    final count = context.read<JobProvider>().savedJobs.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all saved jobs'),
        content: Text(
          'Remove all $count saved ${count == 1 ? 'job' : 'jobs'}? '
          'You can save them again from the job listing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear all', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    final removed = await context.read<JobProvider>().clearSavedJobs();
    if (!mounted) return;
    setState(() => _clearing = false);

    // Reports what actually happened. Any that failed are still in the list.
    final remaining = context.read<JobProvider>().savedJobs.length;
    if (remaining > 0) {
      AppToast.info(context, 'Removed $removed. $remaining could not be removed.');
    } else {
      AppToast.success(context, 'Removed $removed saved ${removed == 1 ? 'job' : 'jobs'}.');
    }
  }
}
