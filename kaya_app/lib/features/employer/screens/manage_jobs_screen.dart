import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Manage Jobs Screen — employer's posted jobs
/// Two tabs: Active (open + in_progress) | History (completed + closed)
class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TODO: Replace with JobProvider
  final List<Map<String, dynamic>> _jobs = [
    {
      'id': 1,
      'title': 'Emergency Pipe Repair',
      'category': 'Plumbing',
      'location': 'Pangasinan',
      'budget': '₱1,200/day',
      'status': 'open',
      'applicants': 5,
      'postedDate': '2 days ago',
      'hasReview': false,
    },
    {
      'id': 2,
      'title': 'House Repainting',
      'category': 'Painting',
      'location': 'Dagupan City',
      'budget': '₱800/day',
      'status': 'in_progress',
      'applicants': 3,
      'workerName': 'Juan Dela Cruz',
      'postedDate': '1 week ago',
      'hasReview': false,
    },
    {
      'id': 3,
      'title': 'Kitchen Cabinet Installation',
      'category': 'Carpentry',
      'location': 'Urdaneta City',
      'budget': '₱2,500/day',
      'status': 'completed',
      'applicants': 8,
      'workerName': 'Maria Santos',
      'completedDate': '2 weeks ago',
      'postedDate': '1 month ago',
      'hasReview': false,
    },
    {
      'id': 4,
      'title': 'Electrical Wiring Repair',
      'category': 'Electrical',
      'location': 'Pangasinan',
      'budget': '₱1,500/day',
      'status': 'completed',
      'applicants': 2,
      'workerName': 'Pedro Cruz',
      'completedDate': '1 month ago',
      'postedDate': '2 months ago',
      'hasReview': true,
    },
    {
      'id': 5,
      'title': 'Garden Landscaping',
      'category': 'Landscaping',
      'location': 'Pangasinan',
      'budget': '₱1,000/day',
      'status': 'closed',
      'applicants': 0,
      'postedDate': '3 months ago',
      'hasReview': false,
    },
  ];

  List<Map<String, dynamic>> get _activeJobs =>
      _jobs.where((j) => j['status'] == 'open' || j['status'] == 'in_progress').toList();

  List<Map<String, dynamic>> get _historyJobs =>
      _jobs.where((j) => j['status'] == 'completed' || j['status'] == 'closed').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            Tab(text: 'Active (${_activeJobs.length})'),
            Tab(text: 'History (${_historyJobs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_activeJobs, isHistory: false),
          _buildList(_historyJobs, isHistory: true),
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
  }

  Widget _buildList(List<Map<String, dynamic>> jobs,
      {required bool isHistory}) {
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
                  style: TextStyle(
                      fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          await Future.delayed(const Duration(seconds: 1)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: jobs.length,
        itemBuilder: (context, i) =>
            _buildCard(jobs[i], isHistory: isHistory),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> job,
      {required bool isHistory}) {
    final status = job['status'] as String;
    final hasReview = job['hasReview'] as bool? ?? false;

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
        onTap: () => Navigator.pushNamed(context, '/job-details'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + status badge ──
              Row(
                children: [
                  Expanded(
                    child: Text(job['title'],
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

              // ── Category + location ──
              Row(
                children: [
                  const Icon(Icons.category_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Text(job['category'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Text(job['location'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                ],
              ),
              const SizedBox(height: 10),

              // ── Budget + applicants ──
              Row(
                children: [
                  Text(job['budget'],
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const Spacer(),
                  if (status != 'closed') ...[
                    const Icon(Icons.people_outline,
                        size: 14, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Text('${job['applicants']} applicants',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
                  ],
                  const SizedBox(width: 8),
                  Text(job['postedDate'],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.neutral400)),
                ],
              ),

              // ── Worker assigned (in_progress / completed) ──
              if (job['workerName'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppColors.neutral400),
                    const SizedBox(width: 4),
                    Text(job['workerName'],
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral600)),
                  ],
                ),
              ],

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
                            arguments: job['id']),
                        icon: const Icon(Icons.people, size: 16),
                        label: Text('Applicants (${job['applicants']})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
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
                        side:
                            const BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Manage',
                          style: TextStyle(fontSize: 13)),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _confirmMarkComplete(job),
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
                hasReview
                    ? Row(
                        children: const [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber),
                          SizedBox(width: 6),
                          Text('Review submitted',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.neutral500,
                                  fontWeight: FontWeight.w500)),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/leave-review',
                            arguments: {
                              'revieweeName': job['workerName'] ?? 'Worker',
                              'revieweeRole': 'worker',
                              'jobTitle': job['title'],
                            },
                          ),
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: const Text('Leave a Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
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
            Text(job['title'],
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text('Choose an action',
                style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
            const SizedBox(height: 20),
            _actionTile(Icons.edit_outlined, 'Edit Job', AppColors.primary,
                () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/edit-job', arguments: {
                'title': job['title'],
                'category': job['category'],
                'description': 'Existing job description...',
                'budget': job['budget'].replaceAll(RegExp(r'[₱/a-zA-Z]'), '').trim(),
                'salaryType': 'Daily',
                'location': job['location'],
                'workersNeeded': job['applicants'] > 0 ? 1 : 1,
                'isUrgent': false,
                'isNegotiable': false,
                'selectedSkills': <String>[],
              });
            }),
            _actionTile(Icons.close, 'Close Job', AppColors.error, () {
              Navigator.pop(context);
              _confirmClose(job);
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
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

  void _confirmMarkComplete(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: Text('Mark "${job['title']}" as completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => job['status'] = 'completed');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Job marked as completed'),
                    backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            child: const Text('Mark Complete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClose(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Job?'),
        content: Text(
            'Close "${job['title']}"? Workers can no longer apply.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => job['status'] = 'closed');
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Job closed')));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Close Job',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
