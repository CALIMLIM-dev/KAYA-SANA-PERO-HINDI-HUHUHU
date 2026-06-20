import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Manage Jobs Screen — employer sees all their posted jobs
class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TODO: Replace with real data from JobProvider
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
    },
    {
      'id': 2,
      'title': 'House Repainting',
      'category': 'Painting',
      'location': 'Dagupan City',
      'budget': '₱800/day',
      'status': 'in_progress',
      'applicants': 3,
      'postedDate': '1 week ago',
    },
    {
      'id': 3,
      'title': 'Kitchen Cabinet Installation',
      'category': 'Carpentry',
      'location': 'Urdaneta City',
      'budget': '₱2,500/day',
      'status': 'completed',
      'applicants': 8,
      'postedDate': '1 month ago',
    },
    {
      'id': 4,
      'title': 'Electrical Wiring Repair',
      'category': 'Electrical',
      'location': 'Pangasinan',
      'budget': '₱1,500/day',
      'status': 'closed',
      'applicants': 2,
      'postedDate': '2 months ago',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterByStatus(String status) =>
      _jobs.where((j) => j['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Jobs',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, '/post-job'),
            tooltip: 'Post a Job',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Open (${_filterByStatus('open').length})'),
            Tab(text: 'In Progress (${_filterByStatus('in_progress').length})'),
            Tab(text: 'Completed (${_filterByStatus('completed').length})'),
            Tab(text: 'Closed (${_filterByStatus('closed').length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobList(_filterByStatus('open')),
          _buildJobList(_filterByStatus('in_progress')),
          _buildJobList(_filterByStatus('completed')),
          _buildJobList(_filterByStatus('closed')),
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

  Widget _buildJobList(List<Map<String, dynamic>> jobs) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text('No jobs here yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            const Text('Post a job to start hiring workers',
                style:
                    TextStyle(fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _buildJobCard(jobs[index]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String;
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
              // Title + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),

              // Category + location
              Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Text(job['category'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Text(job['location'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                ],
              ),
              const SizedBox(height: 12),

              // Budget + applicants + posted date
              Row(
                children: [
                  Text(
                    job['budget'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.people_outline,
                      size: 14, color: AppColors.neutral400),
                  const SizedBox(width: 4),
                  Text(
                    '${job['applicants']} applicants',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral500),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    job['postedDate'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral400),
                  ),
                ],
              ),

              // Actions for open jobs
              if (status == 'open') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, '/view-applicants',
                            arguments: job['id']),
                        icon: const Icon(Icons.people, size: 16),
                        label: Text('View Applicants (${job['applicants']})'),
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
                      onPressed: () =>
                          _showStatusDialog(context, job),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral600,
                        side: const BorderSide(color: AppColors.neutral300),
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
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, Map<String, dynamic> job) {
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
            const Text('What do you want to do with this job?',
                style:
                    TextStyle(fontSize: 13, color: AppColors.neutral600)),
            const SizedBox(height: 20),
            _actionTile(
                Icons.edit_outlined, 'Edit Job', AppColors.primary, () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/job-details');
            }),
            _actionTile(Icons.close, 'Close Job', AppColors.error, () {
              Navigator.pop(context);
              _confirmClose(context, job);
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

  void _confirmClose(BuildContext context, Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Job?'),
        content: Text(
            'Close "${job['title']}"? Workers will no longer be able to apply.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => job['status'] = 'closed');
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job closed')));
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
