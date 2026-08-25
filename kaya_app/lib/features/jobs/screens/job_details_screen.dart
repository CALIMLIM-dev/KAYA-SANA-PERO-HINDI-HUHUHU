import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/job_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../core/constants/credits.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/credits_provider.dart';

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

  final PageController _photoController = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

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

        // Until the job loads there is nothing to build a header from, so this
        // keeps the plain bar — a collapsing photo header that collapses over
        // a spinner just looks broken.
        if (job == null) {
          return Scaffold(
            backgroundColor: AppColors.neutral50,
            appBar: AppBar(
              title: const Text('Job Details',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: provider.isDetailLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.detailErrorMessage != null
                    ? _errorState(provider.detailErrorMessage!)
                    : const SizedBox.shrink(),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.neutral50,
          body: _content(job),
          bottomNavigationBar: _actionBar(job),
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
                  style: const TextStyle(fontSize: 13.5, color: AppColors.neutral400)),
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

  /// Photo → what & how much → who → detail.
  ///
  /// The old order buried the photos two thirds down the page, under the
  /// employer card, so the first thing a worker saw about a job was a wall of
  /// chips. Photos are the fastest way to judge whether work is worth
  /// travelling for, and pay is the second — so those go first and everything
  /// else supports them.
  Widget _content(Job job) {
    return CustomScrollView(
      slivers: [
        _headerSliver(job),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title, pay, key facts ──
              Container(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(job.title,
                              style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.25,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neutral900)),
                        ),
                        if (job.isUrgent) ...[
                          const SizedBox(width: 8),
                          _badge('URGENT', AppColors.error),
                        ],
                      ],
                    ),

                    // Pay sits directly under the title, before anything else.
                    // It is the number the decision turns on.
                    const SizedBox(height: 12),
                    // Wrap rather than a rigid Row+Spacer — a long price plus
                    // the negotiable badge plus the match pill together could
                    // overflow a narrow screen with no way to shrink.
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
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(_periodLabel(job.salaryPeriod),
                                  style: const TextStyle(
                                      fontSize: 13.5, color: AppColors.neutral500)),
                            ),
                          ],
                        ),
                        if (job.isNegotiable)
                          _badge('Open to offers', AppColors.warning),
                        if (job.matchScore != null) _matchPill(job.matchScore!),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.neutral200),
                    const SizedBox(height: 14),

                    /*
                        A labelled list rather than a row of chips.

                        This was six chips in a Wrap — category, place,
                        distance, dates, age and applicant count — all the same
                        size and shape, so nothing was more important than
                        anything else and the distance in kilometres floated
                        loose beside the place it belonged to. Six equal things
                        is a soup; the eye has nothing to sort by.

                        Labels on the left at a fixed width means the values
                        line up in a column, which is what makes a list of
                        facts scannable rather than merely present.
                    */
                    _detailRow(
                      'Location',
                      [
                        if ((job.location ?? '').isNotEmpty) job.location!,
                        // Merged into the place it describes. On its own it
                        // read as a stray measurement of nothing in
                        // particular.
                        if (job.distance != null) formatDistance(job.distance!),
                      ].join('  ·  '),
                    ),
                    if (job.scheduleLabel != null)
                      _detailRow('Schedule', job.scheduleLabel!),
                    if (job.category != null)
                      _detailRow('Category', job.category!),
                    if (job.postedAt != null)
                      _detailRow('Posted', _timeAgo(job.postedAt!)),
                    _detailRow(
                      'Applicants',
                      '${job.applicantCount}',
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

          // ── Description ──
          if ((job.description ?? '').isNotEmpty)
            _section(
              title: 'Job Description',
              child: Text(job.description!,
                  style: const TextStyle(
                      fontSize: 14, height: 1.6, color: AppColors.neutral700)),
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
                                fontSize: 13.5,
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

              // Applicant count moved up into the facts row — it was a whole
              // card of its own for one short sentence.
              const SizedBox(height: 90), // clears the bottom action bar
            ],
          ),
        ),
      ],
    );
  }

  /// Photo carousel as a collapsing header, or a plain bar when there are none.
  ///
  /// Edge to edge and 300 tall: a job photo shrunk into a rounded card halfway
  /// down the page tells you almost nothing about the work, which is what the
  /// previous layout did.
  Widget _headerSliver(Job job) {
    final photos = job.photoUrls;

    final actions = [
      if (!job.isOwnJob)
        IconButton(
          icon: Icon(job.isSaved ? Icons.bookmark : Icons.bookmark_border),
          tooltip: job.isSaved ? 'Saved' : 'Save this job',
          onPressed: _isSaving ? null : () => _toggleSave(job),
        ),
    ];

    if (photos.isEmpty) {
      return SliverAppBar(
        pinned: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Job Details',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        actions: actions,
      );
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _photoController,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _photoIndex = i),
              itemBuilder: (context, i) => Image.network(
                photos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.neutral200,
                  child: const Icon(Icons.broken_image_outlined,
                      size: 48, color: AppColors.neutral400),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: AppColors.neutral100,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
            ),

            // Keeps the back arrow and save icon legible over a bright photo.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (photos.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    photos.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _photoIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _photoIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One fact about the job: a muted label, then the value.
  ///
  /// The label column is a fixed width so every value starts at the same x,
  /// which is the whole reason this reads as organised and a Wrap of chips
  /// does not.
  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.neutral900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
            : Builder(
                builder: (context) {
                  /*
                      The price is on the button, not behind it.

                      Somebody deciding whether to apply should know what it
                      costs while they are deciding, and an app that only
                      mentions a fee after taking it feels like a trick even
                      when the fee is four pesos.
                  */
                  final credits = context.watch<CreditsProvider>();
                  final cost = credits.costOf('apply');

                  if (cost == null) return const Text('Apply Now');

                  /*
                      Free credits waiting is not the same as being broke.

                      Somebody who has never opened the wallet has an empty
                      balance and a gift sitting there unclaimed, and telling
                      them to buy something would be both wrong and the worst
                      possible first impression.
                  */
                  if (credits.hasSomethingToClaim) {
                    return const Text('Claim your free Barya');
                  }

                  if (!credits.canAfford('apply')) {
                    return const Text('Top up to apply');
                  }

                  return Text('Apply Now  ·  ${Credits.amount(cost)}');
                },
              ),
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
    final credits = context.read<CreditsProvider>();

    // No point firing a request that is certain to come back 402. Send them
    // where they can do something about it instead.
    // Unclaimed credits go to the wallet too, but to claim rather than buy.
    if (credits.hasLoadedOnce &&
        (credits.hasSomethingToClaim || !credits.canAfford('apply'))) {
      await Navigator.pushNamed(context, AppRouter.wallet);
      if (!mounted) return;
      await credits.refresh();
      return;
    }

    setState(() => _isApplying = true);
    final applications = context.read<ApplicationProvider>();
    final success = await applications.applyToJob(job.id);

    if (!mounted) return;
    setState(() => _isApplying = false);

    if (success) {
      await context.read<JobProvider>().fetchJobDetail(job.id);
      if (!mounted) return;

      // The balance just changed. Refetched rather than decremented locally,
      // because this is the one number that has to be right.
      await credits.refresh();
      if (!mounted) return;

      AppToast.success(context, 'Application submitted!');
      return;
    }

    // The wallet emptied between opening the screen and tapping, or the
    // balance was never loaded. Either way, offer the fix rather than the
    // failure.
    final failure = applications.lastApplyError;

    if (failure != null && failure.isInsufficientCredits) {
      await credits.refresh();
      if (!mounted) return;

      final goToWallet = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Not enough ${Credits.plural}'),
          content: Text(failure.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Top up'),
            ),
          ],
        ),
      );

      if (goToWallet == true && mounted) {
        await Navigator.pushNamed(context, AppRouter.wallet);
        if (mounted) await credits.refresh();
      }
      return;
    }

    AppToast.error(context, applications.errorMessage ?? 'Could not submit application');
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
      AppToast.error(context, jobProvider.errorMessage ?? 'Something went wrong');
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
