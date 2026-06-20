import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// My Applications Screen — Worker sees all their job applications
/// Tabs: Pending, Accepted, Rejected, Withdrawn
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TODO: Replace with ApplicationProvider data
  final List<Map<String, dynamic>> _applications = [
    {
      'id': 1,
      'jobTitle': 'Emergency Pipe Repair',
      'company': 'Plumbing Services Inc.',
      'location': 'Pangasinan',
      'appliedDate': '2 days ago',
      'status': 'pending',
      'salary': '₱1,200/day',
      'isVerified': true,
    },
    {
      'id': 2,
      'jobTitle': 'Electrician Needed',
      'company': 'Tech Solutions Inc.',
      'location': 'Dagupan City',
      'appliedDate': '5 days ago',
      'status': 'pending',
      'salary': '₱1,800/day',
      'isVerified': true,
    },
    {
      'id': 3,
      'jobTitle': 'House Painting',
      'company': 'Private Homeowner',
      'location': 'Urdaneta City',
      'appliedDate': '1 week ago',
      'status': 'pending',
      'salary': '₱800/day',
      'isVerified': false,
    },
    {
      'id': 4,
      'jobTitle': 'Carpenter for Kitchen Cabinets',
      'company': 'Baliwag Construction',
      'location': 'Pangasinan',
      'appliedDate': '3 days ago',
      'acceptedDate': '1 day ago',
      'status': 'accepted',
      'salary': '₱2,500/day',
      'isVerified': true,
    },
    {
      'id': 5,
      'jobTitle': 'AC Repair Technician',
      'company': 'Cool Air Services',
      'location': 'Dagupan City',
      'appliedDate': '1 week ago',
      'acceptedDate': '5 days ago',
      'status': 'accepted',
      'salary': '₱1,500/day',
      'isVerified': true,
    },
    {
      'id': 6,
      'jobTitle': 'Welder for Metal Gates',
      'company': 'Steel Works Co.',
      'location': 'Urdaneta City',
      'appliedDate': '2 weeks ago',
      'rejectedDate': '1 week ago',
      'status': 'rejected',
      'salary': '₱1,000/day',
      'isVerified': true,
    },
    {
      'id': 7,
      'jobTitle': 'Roof Repair',
      'company': 'QuickFix Solutions',
      'location': 'Pangasinan',
      'appliedDate': '3 weeks ago',
      'status': 'withdrawn',
      'salary': '₱900/day',
      'isVerified': false,
    },
  ];

  List<Map<String, dynamic>> _byStatus(String status) =>
      _applications.where((a) => a['status'] == status).toList();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Applications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Pending (${_byStatus('pending').length})'),
            Tab(text: 'Accepted (${_byStatus('accepted').length})'),
            Tab(text: 'Rejected (${_byStatus('rejected').length})'),
            Tab(text: 'Withdrawn (${_byStatus('withdrawn').length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(_byStatus('pending')),
          _buildTab(_byStatus('accepted')),
          _buildTab(_byStatus('rejected')),
          _buildTab(_byStatus('withdrawn')),
        ],
      ),
    );
  }

  Widget _buildTab(List<Map<String, dynamic>> apps) {
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            const Text(
              'No applications here',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse jobs and start applying',
              style: TextStyle(fontSize: 14, color: AppColors.neutral400),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Browse Jobs',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: apps.length,
        itemBuilder: (context, index) => _buildCard(apps[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> app) {
    final status = app['status'] as String;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      app['jobTitle'],
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
              const SizedBox(height: 6),

              // ── Company + verified ──
              Row(
                children: [
                  Text(
                    app['company'],
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.neutral600),
                  ),
                  if (app['isVerified'] == true) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified,
                        size: 13, color: AppColors.success),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // ── Location + salary ──
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 3),
                  Text(app['location'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                  const SizedBox(width: 12),
                  const Icon(Icons.payments_outlined,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 3),
                  Text(
                    app['salary'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Dates ──
              Text(
                'Applied ${app['appliedDate']}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral400),
              ),
              if (app['acceptedDate'] != null)
                Text(
                  'Accepted ${app['acceptedDate']}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.success),
                ),
              if (app['rejectedDate'] != null)
                Text(
                  'Rejected ${app['rejectedDate']}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.error),
                ),

              // ── Action buttons ──
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _confirmWithdraw(app),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Withdraw'),
                  ),
                ),
              ],

              if (status == 'accepted') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/messages'),
                    icon: const Icon(Icons.message_outlined, size: 16),
                    label: const Text('Message Employer'),
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
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Pending';
        break;
      case 'accepted':
        color = AppColors.success;
        label = 'Accepted';
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Rejected';
        break;
      case 'withdrawn':
        color = AppColors.neutral400;
        label = 'Withdrawn';
        break;
      default:
        color = AppColors.neutral400;
        label = status;
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

  void _confirmWithdraw(Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Withdraw Application?'),
        content: Text(
            'Withdraw your application for "${app['jobTitle']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => app['status'] = 'withdrawn');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Application withdrawn'),
                  backgroundColor: AppColors.neutral600,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}
