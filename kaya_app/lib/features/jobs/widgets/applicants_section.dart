import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../applications/widgets/applicant_card.dart';

/*
    The people who applied, on the employer's home screen.

    The panel's point and the user's: an employer should not walk Manage
    Jobs, then Applicants, then a tap per person to learn who any of them
    are. Their newest running job with somebody waiting, best match first,
    with the same card and the same Accept and Reject as the Applicants
    screen - three of them, then See all.
*/
class ApplicantsSection extends StatefulWidget {
  const ApplicantsSection({super.key, this.maxRows = 3});

  final int maxRows;

  @override
  State<ApplicantsSection> createState() => _ApplicantsSectionState();
}

class _ApplicantsSectionState extends State<ApplicantsSection> {
  /// The job last asked about, so a rebuild does not refetch.
  int? _asked;

  /// The newest running job that has applicants waiting on a decision.
  static Map<String, dynamic>? _jobWithApplicants(JobProvider jobs) {
    for (final job in jobs.activeJobs) {
      final waiting = (job['pending_application_count'] as num?)?.toInt() ?? 0;
      if (waiting > 0) return job;
    }
    return null;
  }

  void _askFor(int jobId) {
    if (_asked == jobId) return;
    _asked = jobId;

    // After the frame: this runs inside the home screen's build, and a
    // provider that notifies during a build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final applications = context.read<ApplicationProvider>();
      if (applications.homeApplicantsJobId != jobId) {
        applications.fetchHomeApplicants(jobId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    if (!appMode.hasEmployerProfile ||
        !appMode.effectiveMode.showsEmployerSide) {
      return const SizedBox.shrink();
    }

    final job = _jobWithApplicants(context.watch<JobProvider>());
    final jobId = job == null ? null : (job['id'] as num?)?.toInt();
    if (jobId == null) return const SizedBox.shrink();

    _askFor(jobId);

    final applications = context.watch<ApplicationProvider>();

    // Only this job's people. Another job's applicants under this job's
    // title, with Accept beside them, would be worse than nothing.
    if (applications.homeApplicantsJobId != jobId) {
      return const SizedBox.shrink();
    }

    final rows = applications.homeApplicants;
    if (rows.isEmpty) return const SizedBox.shrink();

    final title = (job!['title'] ?? 'your job').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Applicants',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => AppRouter.push(
                  context,
                  AppRouter.viewApplicants,
                  arguments: {'jobId': jobId},
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(rows.length > widget.maxRows
                    ? 'See all ${rows.length}'
                    : 'See all'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              // Which job these are for, for an employer running two.
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
            ),
          ),
          for (final row in rows.take(widget.maxRows))
            ApplicantCard(
              applicant: row,
              showActions: true,
              perWorkerActions: false,
              jobId: jobId,
              jobTitle: title,
              onChanged: () async {
                await context.read<ApplicationProvider>().fetchHomeApplicants(jobId);
              },
            ),
        ],
      ),
    );
  }
}
