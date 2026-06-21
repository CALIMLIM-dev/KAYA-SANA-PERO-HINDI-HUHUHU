import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// View Applicants Screen — employer sees all workers who applied to a job
class ViewApplicantsScreen extends StatefulWidget {
  const ViewApplicantsScreen({super.key});

  @override
  State<ViewApplicantsScreen> createState() => _ViewApplicantsScreenState();
}

class _ViewApplicantsScreenState extends State<ViewApplicantsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TODO: Replace with real data from Provider
  final List<Map<String, dynamic>> _applicants = [
    {
      'name': 'Juan Dela Cruz',
      'skills': ['Plumbing', 'Pipe Repair', 'Leak Detection'],
      'experience': '5 years',
      'location': 'Pangasinan',
      'rating': 4.9,
      'reviewCount': 127,
      'isVerified': true,
      'status': 'pending',
      'appliedDate': '2 hours ago',
    },
    {
      'name': 'Pedro Santos',
      'skills': ['Plumbing', 'Installation'],
      'experience': '3 years',
      'location': 'Dagupan City',
      'rating': 4.6,
      'reviewCount': 45,
      'isVerified': true,
      'status': 'pending',
      'appliedDate': '5 hours ago',
    },
    {
      'name': 'Mario Reyes',
      'skills': ['Pipe Repair', 'Emergency Service'],
      'experience': '7 years',
      'location': 'Urdaneta City',
      'rating': 4.8,
      'reviewCount': 89,
      'isVerified': false,
      'status': 'pending',
      'appliedDate': '1 day ago',
    },
    {
      'name': 'Carlos Mendoza',
      'skills': ['Plumbing', 'Pipe Repair', 'Installation', 'Leak Detection'],
      'experience': '10 years',
      'location': 'Pangasinan',
      'rating': 5.0,
      'reviewCount': 201,
      'isVerified': true,
      'status': 'accepted',
      'appliedDate': '2 days ago',
    },
    {
      'name': 'Roberto Cruz',
      'skills': ['Plumbing'],
      'experience': '1 year',
      'location': 'San Carlos City',
      'rating': 4.2,
      'reviewCount': 12,
      'isVerified': false,
      'status': 'rejected',
      'appliedDate': '3 days ago',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _byStatus(String status) =>
      _applicants.where((a) => a['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
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
            Tab(text: 'Pending (${_byStatus('pending').length})'),
            Tab(text: 'Accepted (${_byStatus('accepted').length})'),
            Tab(text: 'Rejected (${_byStatus('rejected').length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_byStatus('pending'), showActions: true),
          _buildList(_byStatus('accepted'), showActions: false),
          _buildList(_byStatus('rejected'), showActions: false),
        ],
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: applicants.length,
      itemBuilder: (context, index) =>
          _buildApplicantCard(applicants[index], showActions: showActions),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> applicant,
      {required bool showActions}) {
    final status = applicant['status'] as String;

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
            // ── Header: avatar + name + rating ──
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    applicant['name'].toString().split(' ').first[0],
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
                          Text(
                            applicant['name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900,
                            ),
                          ),
                          if (applicant['isVerified'] == true) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                size: 15, color: AppColors.success),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '${applicant['rating']} (${applicant['reviewCount']} reviews)',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.neutral500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge for non-pending
                if (status != 'pending') _statusBadge(status),
              ],
            ),

            const SizedBox(height: 12),

            // ── Info row ──
            Row(
              children: [
                Icon(Icons.work_outline,
                    size: 13, color: AppColors.neutral400),
                const SizedBox(width: 4),
                Text(applicant['experience'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral500)),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.neutral400),
                const SizedBox(width: 4),
                Text(applicant['location'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral500)),
                const Spacer(),
                Text(applicant['appliedDate'],
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.neutral400)),
              ],
            ),

            const SizedBox(height: 10),

            // ── Skills ──
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (applicant['skills'] as List<String>)
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

            // ── Action buttons for pending ──
            if (showActions) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(
                          context, '/applicant-review',
                          arguments: applicant),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('View Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptApplicant(applicant),
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
                  ElevatedButton(
                    onPressed: () => _rejectApplicant(applicant),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],

            // ── Message button for accepted ──
            if (status == 'accepted') ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/messages'),
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

  void _acceptApplicant(Map<String, dynamic> applicant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Applicant?'),
        content: Text(
            'Accept ${applicant['name']}? Messaging will be unlocked between you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => applicant['status'] = 'accepted');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${applicant['name']} accepted'),
                backgroundColor: AppColors.success,
              ));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            child: const Text('Accept',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _rejectApplicant(Map<String, dynamic> applicant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Applicant?'),
        content: Text('Reject ${applicant['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => applicant['status'] = 'rejected');
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Applicant rejected')));
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
