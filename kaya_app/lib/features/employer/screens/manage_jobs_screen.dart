import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/job_provider.dart';

/// Manage Jobs Screen — employer's posted jobs, on real data from JobProvider.
///
/// This is the screen the home screen's "Active Jobs" card and the bottom-nav
/// entry point to /manage-jobs both land on. It used to render a hardcoded list
/// of five fake jobs regardless of what the employer actually posted — a real
/// job created via Post a Job never appeared here.
///
/// Two tabs: Active (open + in_progress) | History (completed + closed)
class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<JobProvider>().fetchMyJobs(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _statusOf(Map<String, dynamic> job) => (job['status'] ?? '').toString();

  List<Map<String, dynamic>> _activeJobs(List<Map<String, dynamic>> jobs) =>
      jobs.where((j) {
        final s = _statusOf(j);
        return s == 'open' || s == 'in_progress';
      }).toList();

  List<Map<String, dynamic>> _historyJobs(List<Map<String, dynamic>> jobs) =>
      jobs.where((j) {
        final s = _statusOf(j);
        return s == 'completed' || s == 'closed';
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobProvider, _) {
        final jobs = jobProvider.jobs;
        final active = _activeJobs(jobs);
        final history = _historyJobs(jobs);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('My Jobs',
                style: TextStyle(fontWeight: FontWeight.w600)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: 'Active (${active.length})'),
                Tab(text: 'History (${history.length})'),
              ],
            ),
          ),
          body: jobProvider.isLoading && jobs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : jobProvider.errorMessage != null && jobs.isEmpty
                  ? _errorState(jobProvider.errorMessage!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(active, isHistory: false),
                        _buildList(history, isHistory: true),
                      ],
                    ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/post-job'),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Post a Job',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
            const Text('Could not load your jobs',
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
              onPressed: () => context.read<JobProvider>().fetchMyJobs(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> jobs, {required bool isHistory}) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(
              isHistory ? 'No past jobs yet' : 'No active jobs',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600),
            ),
            const SizedBox(height: 8),
            if (!isHistory)
              const Text('Post a job to start hiring workers',
                  style: TextStyle(fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<JobProvider>().fetchMyJobs(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: jobs.length,
        itemBuilder: (context, i) => _buildCard(jobs[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> job) {
    final status = _statusOf(job);
    final jobId = job['id'] as int;
    final title = (job['title'] ?? '').toString();
    final category = (job['category'] as Map<String, dynamic>?)?['name']?.toString();
    final location = (job['city'] ?? job['location'] ?? '').toString();
    final applicants = (job['application_count'] as num?)?.toInt() ?? 0;
    final budget = _formatBudget(job);
    final postedAgo = _timeAgo(job['created_at'] as String?);

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
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/job-details',
            arguments: {'jobId': jobId}),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral900)),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (category != null) ...[
                    const Icon(Icons.category_outlined,
                        size: 13, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Text(category,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
                    const SizedBox(width: 12),
                  ],
                  if (location.isNotEmpty) ...[
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral500)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (budget != null)
                    Text(budget,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  const Spacer(),
                  if (status != 'closed') ...[
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Text('$applicants applicant${applicants == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
                  ],
                  if (postedAgo != null) ...[
                    const SizedBox(width: 8),
                    Text(postedAgo,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.neutral400)),
                  ],
                ],
              ),

              // ── Actions ──
              if (status == 'open') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, '/view-applicants',
                            arguments: {'jobId': jobId}),
                        icon: const Icon(Icons.people, size: 16),
                        label: Text('Applicants ($applicants)'),
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
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _showManageSheet(job),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral600,
                        side: const BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Manage', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ] else if (status == 'in_progress') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/messages'),
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const Text('Message Worker'),
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
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _confirmMarkComplete(jobId, title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Mark Complete',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ] else if (status == 'completed') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, '/view-applicants',
                        arguments: {'jobId': jobId}),
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('View Applicants & Leave a Review'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "₱1,500 - ₱2,500/day" or "₱1,500/day" when there is no max, or null when
  /// nothing was set. Fields come back from the API as numeric strings.
  String? _formatBudget(Map<String, dynamic> job) {
    double? asDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    final min = asDouble(job['budget_min']);
    final max = asDouble(job['budget_max']);

    if (min == null && max == null) return null;

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

    if (min != null && max != null && max != min) {
      return '₱${fmt(min)} - ₱${fmt(max)}';
    }
    return '₱${fmt(min ?? max!)}';
  }

  String? _timeAgo(String? isoDate) {
    if (isoDate == null) return null;
    final date = DateTime.tryParse(isoDate);
    if (date == null) return null;

    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'open':
        color = AppColors.success;
        label = 'Open';
        break;
      case 'in_progress':
        color = AppColors.warning;
        label = 'In Progress';
        break;
      case 'completed':
        color = AppColors.primary;
        label = 'Completed';
        break;
      default:
        color = AppColors.neutral400;
        label = 'Closed';
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

  void _showManageSheet(Map<String, dynamic> job) {
    final jobId = job['id'] as int;
    final category = job['category'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((job['title'] ?? '').toString(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text('Choose an action',
                style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
            const SizedBox(height: 20),
            _actionTile(Icons.edit_outlined, 'Edit Job', AppColors.primary, () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/edit-job', arguments: {
                'id': jobId,
                'title': job['title'],
                'category': category?['name'],
                'category_id': category?['id'],
                'description': job['description'],
                'budget_min': job['budget_min'],
                'location': job['city'] ?? job['location'],
                'location_id': job['location_id'],
              });
            }),
            _actionTile(Icons.close, 'Close Job', AppColors.error, () {
              Navigator.pop(context);
              _confirmClose(jobId, (job['title'] ?? '').toString());
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
    );
  }

  void _confirmMarkComplete(int jobId, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: Text('Mark "$title" as completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok =
                  await context.read<JobProvider>().changeStatus(jobId, 'completed');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Job marked as completed'
                    : context.read<JobProvider>().errorMessage ??
                        'Failed to update job'),
                backgroundColor: ok ? AppColors.success : AppColors.error,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClose(int jobId, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Job?'),
        content: Text('Close "$title"? Workers can no longer apply.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok =
                  await context.read<JobProvider>().changeStatus(jobId, 'closed');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Job closed'
                    : context.read<JobProvider>().errorMessage ??
                        'Failed to close job'),
                backgroundColor: ok ? null : AppColors.error,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child:
                const Text('Close Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
