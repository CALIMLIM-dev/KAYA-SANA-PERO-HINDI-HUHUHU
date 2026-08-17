import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';

/// Job Details — a single real job, fetched via GET /jobs/{id}.
///
/// Previously this was a StatelessWidget showing the same hardcoded
/// "Emergency Pipe Repair" regardless of which job card was tapped, with no
/// route argument reading at all, and a decorative Apply button that did
/// nothing. Every job card in the app links here.
class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({super.key});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  int? _jobId;
  bool _initialized = false;
  bool _isApplying = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _jobId = args is Map ? args['jobId'] as int? : args as int?;

    if (_jobId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<JobProvider>().fetchJobDetail(_jobId!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: Text('No job specified.')),
      );
    }

    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        final job = provider.selectedJob;

        return Scaffold(
          backgroundColor: AppColors.neutral50,
          appBar: AppBar(
            title: const Text('Job Details',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (job != null && !job.isOwnJob)
                IconButton(
                  icon: Icon(job.isSaved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _isSaving ? null : () => _toggleSave(job),
                ),
            ],
          ),
          body: provider.isDetailLoading && job == null
              ? const Center(child: CircularProgressIndicator())
              : provider.detailErrorMessage != null && job == null
                  ? _errorState(provider.detailErrorMessage!)
                  : job == null
                      ? const SizedBox.shrink()
                      : _content(job),
          bottomNavigationBar: job == null ? null : _actionBar(job),
        );
      },
    );
  }

  Widget _errorState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.neutral300),
              const SizedBox(height: 16),
              const Text('Could not load this job',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral600)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral400)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () =>
                    context.read<JobProvider>().fetchJobDetail(_jobId!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _content(Job job) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Header card: title, badges, salary ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(job.title,
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900)),
                    ),
                    if (job.isUrgent) ...[
                      const SizedBox(width: 8),
                      _badge('URGENT', AppColors.error),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (job.category != null) _iconChip(Icons.category_outlined, job.category!),
                    if ((job.location ?? '').isNotEmpty)
                      _iconChip(Icons.location_on_outlined, job.location!),
                    if (job.postedAt != null)
                      _iconChip(Icons.schedule, _timeAgo(job.postedAt!)),
                  ],
                ),
                const SizedBox(height: 14),
                // Wrap rather than a rigid Row+Spacer — a long price plus the
                // negotiable badge plus the match pill together could overflow
                // a narrow screen with no way to shrink; this just wraps
                // instead of erroring.
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatSalary(job.salaryMin, job.salaryMax),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(_periodLabel(job.salaryPeriod),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.neutral500)),
                        ),
                      ],
                    ),
                    if (job.isNegotiable) _badge('Open to offers', AppColors.warning),
                    if (job.matchScore != null) _matchPill(job.matchScore!),
                  ],
                ),
              ],
            ),
          ),

          // ── Posted by ──
          _section(
            child: InkWell(
              onTap: job.employerId == null
                  ? null
                  : () => Navigator.pushNamed(context, '/employer-profile',
                      arguments: {'employerId': job.employerId}),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      job.company.isNotEmpty ? job.company[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job.company.isEmpty ? 'Private Employer' : job.company,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.neutral900),
                              ),
                            ),
                            if (job.requiresVerification) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 15, color: AppColors.success),
                            ],
                          ],
                        ),
                        const Text('Posted by',
                            style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                      ],
                    ),
                  ),
                  if (job.employerId != null)
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.neutral400),
                ],
              ),
            ),
          ),

          // ── Photos ──
          if (job.photoUrls.isNotEmpty)
            _section(
              title: 'Photos',
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: job.photoUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      job.photoUrls[i],
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 220,
                        height: 160,
                        color: AppColors.neutral100,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.neutral400),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Description ──
          if ((job.description ?? '').isNotEmpty)
            _section(
              title: 'Job Description',
              child: Text(job.description!,
                  style: const TextStyle(
                      fontSize: 14.5, height: 1.6, color: AppColors.neutral700)),
            ),

          // ── Required skills ──
          if (job.requiredSkills.isNotEmpty)
            _section(
              title: 'Required Skills',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: job.requiredSkills.map((s) {
                  final matched = job.matchedSkills
                      .any((m) => m.toLowerCase() == s.toLowerCase());
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: matched
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: matched
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.neutral200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (matched)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(Icons.check_circle,
                                size: 13, color: AppColors.success),
                          ),
                        Text(s,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: matched
                                    ? AppColors.success
                                    : AppColors.neutral700)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Applicant count ──
          _section(
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: AppColors.neutral500),
                const SizedBox(width: 8),
                Text('${job.applicantCount} applicant${job.applicantCount == 1 ? '' : 's'} so far',
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
              ],
            ),
          ),

          const SizedBox(height: 90), // clears the bottom action bar
        ],
      ),
    );
  }

  Widget _section({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.neutral600),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral700)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _matchPill(int score) {
    final color = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.neutral500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$score% match',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// The action bar at the bottom of the screen — what it shows depends
  /// entirely on the real state of the job, not a static button.
  Widget _actionBar(Job job) {
    Widget button;

    if (job.isOwnJob) {
      button = OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/view-applicants',
            arguments: {'jobId': job.id}),
        icon: const Icon(Icons.people_outline),
        label: Text('View ${job.applicantCount} Applicant${job.applicantCount == 1 ? '' : 's'}'),
        style: _actionStyle(outlined: true),
      );
    } else if (!job.isActive) {
      button = ElevatedButton(
        onPressed: null,
        style: _actionStyle(),
        child: const Text('This job is no longer open'),
      );
    } else if (job.hasApplied) {
      final status = job.applicationStatus;
      final (label, color) = switch (status) {
        ApplicationStatus.accepted => ('Application Accepted', AppColors.success),
        ApplicationStatus.rejected => ('Application Not Selected', AppColors.error),
        ApplicationStatus.withdrawn => ('Application Withdrawn', AppColors.neutral500),
        _ => ('Application Pending', AppColors.warning),
      };
      button = ElevatedButton(
        onPressed: null,
        style: _actionStyle(backgroundColor: color.withValues(alpha: 0.15)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      );
    } else {
      button = ElevatedButton(
        onPressed: _isApplying ? null : () => _apply(job),
        style: _actionStyle(),
        child: _isApplying
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Apply Now'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(top: false, child: SizedBox(width: double.infinity, child: button)),
    );
  }

  ButtonStyle _actionStyle({bool outlined = false, Color? backgroundColor}) {
    return outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: backgroundColor ?? AppColors.neutral300,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          );
  }

  Future<void> _apply(Job job) async {
    setState(() => _isApplying = true);
    final applications = context.read<ApplicationProvider>();
    final success = await applications.applyToJob(job.id);

    if (!mounted) return;
    setState(() => _isApplying = false);

    if (success) {
      await context.read<JobProvider>().fetchJobDetail(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Application submitted!'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(applications.errorMessage ?? 'Could not submit application'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _toggleSave(Job job) async {
    setState(() => _isSaving = true);
    final jobProvider = context.read<JobProvider>();
    final ok = job.isSaved ? await jobProvider.unsaveJob(job.id) : await jobProvider.saveJob(job.id);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      await jobProvider.fetchJobDetail(job.id);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(jobProvider.errorMessage ?? 'Something went wrong'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  String _periodLabel(String period) => switch (period) {
        'daily' => '/ day',
        'hourly' => '/ hour',
        _ => '/ project',
      };

  String _formatSalary(double? min, double? max) {
    String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    if (min == null && max == null) return 'Negotiable';
    if (min != null && max != null && max != min) {
      return '₱${fmt(min)} - ₱${fmt(max)}';
    }
    return '₱${fmt(min ?? max!)}';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
