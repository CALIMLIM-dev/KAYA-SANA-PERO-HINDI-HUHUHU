import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/json_parse.dart';
import '../../../providers/application_provider.dart';

/// View Applicants Screen — employer sees everyone who actually applied to a
/// job, via GET /jobs/{job}/applicants.
///
/// This used to render five hardcoded applicants (Juan Dela Cruz, Pedro
/// Santos, Mario Reyes...) on every job regardless of who applied, and Accept/
/// Reject only flipped local state — nothing was sent to the server.
class ViewApplicantsScreen extends StatefulWidget {
  const ViewApplicantsScreen({super.key});

  @override
  State<ViewApplicantsScreen> createState() => _ViewApplicantsScreenState();
}

class _ViewApplicantsScreenState extends State<ViewApplicantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _jobId;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        (_) => context.read<ApplicationProvider>().fetchApplicants(_jobId!),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _byStatus(
          List<Map<String, dynamic>> applicants, String status) =>
      applicants.where((a) => a['application_status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    if (_jobId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Applicants')),
        body: const Center(child: Text('No job specified.')),
      );
    }

    return Consumer<ApplicationProvider>(
      builder: (context, provider, _) {
        final all = provider.applicants;
        final pending = _byStatus(all, 'pending');
        final accepted = _byStatus(all, 'accepted');
        final rejected = _byStatus(all, 'rejected');

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Applicants',
                style: TextStyle(fontWeight: FontWeight.w600)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Accepted (${accepted.length})'),
                Tab(text: 'Rejected (${rejected.length})'),
              ],
            ),
          ),
          body: provider.isApplicantsLoading && all.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.applicantsErrorMessage != null && all.isEmpty
                  ? _errorState(provider.applicantsErrorMessage!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(pending, showActions: true),
                        _buildList(accepted, showActions: false),
                        _buildList(rejected, showActions: false),
                      ],
                    ),
        );
      },
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('Could not load applicants',
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
                  context.read<ApplicationProvider>().fetchApplicants(_jobId!),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> applicants,
      {required bool showActions}) {
    if (applicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('No applicants here',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<ApplicationProvider>().fetchApplicants(_jobId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: applicants.length,
        itemBuilder: (context, index) =>
            _buildApplicantCard(applicants[index], showActions: showActions),
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> applicant,
      {required bool showActions}) {
    final status = (applicant['application_status'] ?? 'pending').toString();
    final name = (applicant['worker_name'] ?? 'Worker').toString();
    // worker_rating comes from WorkerProfile.rating_avg, a Laravel decimal
    // cast — it arrives as the string "0.00", so a plain `as num?` threw and
    // took the whole applicants list down.
    final rating = asDouble(applicant['worker_rating']);
    final reviewCount = asInt(applicant['worker_rating_count']);
    final isVerified = applicant['is_verified'] as bool? ?? false;
    final skills = (applicant['skills'] as List?)
            ?.map((s) => s.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final applicationId = applicant['application_id'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
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
                            child: Text(name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral900,
                                )),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                size: 15, color: AppColors.success),
                          ],
                        ],
                      ),
                      if (reviewCount > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.neutral500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (status != 'pending') _statusBadge(status),
              ],
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary)),
                        ))
                    .toList(),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmRespond(applicationId, name,
                          accept: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmRespond(applicationId, name,
                          accept: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/messages'),
                  icon: const Icon(Icons.message_outlined, size: 16),
                  label: const Text('Send Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = AppColors.success;
        label = 'Accepted';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Rejected';
        break;
      default:
        color = AppColors.warning;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _confirmRespond(int applicationId, String name, {required bool accept}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(accept ? 'Accept Applicant?' : 'Reject Applicant?'),
        content: Text(accept
            ? 'Accept $name? Messaging will be unlocked between you.'
            : 'Reject $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ApplicationProvider>();
              final ok = await provider.respondToApplicant(applicationId,
                  accept: accept);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? '$name ${accept ? 'accepted' : 'rejected'}'
                    : provider.applicantsErrorMessage ?? 'Something went wrong'),
                backgroundColor: ok
                    ? (accept ? AppColors.success : null)
                    : AppColors.error,
              ));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accept ? AppColors.success : AppColors.error),
            child: Text(accept ? 'Accept' : 'Reject',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
