import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// My Invitations Screen — Worker sees job invitations from employers
/// Can Accept or Decline each invitation
class MyInvitationsScreen extends StatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  State<MyInvitationsScreen> createState() => _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends State<MyInvitationsScreen> {
  // TODO: Replace with InvitationProvider data
  final List<Map<String, dynamic>> _invitations = [
    {
      'id': 1,
      'status': 'pending',
      'receivedDate': '2 hours ago',
      'jobTitle': 'Emergency Pipe Repair',
      'jobBudget': '₱1,200/day',
      'jobLocation': 'Pangasinan',
      'jobDescription': 'We need an experienced plumber to fix a burst pipe in our residential property.',
      'employerName': 'Plumbing Services Inc.',
      'employerVerified': true,
    },
    {
      'id': 2,
      'status': 'pending',
      'receivedDate': '1 day ago',
      'jobTitle': 'Bathroom Renovation',
      'jobBudget': '₱2,500/day',
      'jobLocation': 'Dagupan City',
      'jobDescription': 'Full bathroom renovation project including tile work and fixture installation.',
      'employerName': 'Home Builders Co.',
      'employerVerified': true,
    },
    {
      'id': 3,
      'status': 'accepted',
      'receivedDate': '3 days ago',
      'jobTitle': 'Kitchen Plumbing Repair',
      'jobBudget': '₱900/day',
      'jobLocation': 'Urdaneta City',
      'jobDescription': 'Kitchen sink and dishwasher plumbing repair needed.',
      'employerName': 'Private Homeowner',
      'employerVerified': false,
    },
    {
      'id': 4,
      'status': 'declined',
      'receivedDate': '1 week ago',
      'jobTitle': 'Swimming Pool Plumbing',
      'jobBudget': '₱1,800/day',
      'jobLocation': 'San Carlos City',
      'jobDescription': 'Pool pump and filtration system repair.',
      'employerName': 'Aqua Solutions',
      'employerVerified': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Invitations',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _invitations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async =>
                  await Future.delayed(const Duration(seconds: 1)),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invitations.length,
                itemBuilder: (_, i) => _buildCard(_invitations[i]),
              ),
            ),
    );
  }

  // ─── empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('No Invitations Yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 8),
            const Text(
              'When employers invite you to jobs, they\'ll appear here',
              style: TextStyle(
                  fontSize: 14, color: AppColors.neutral600, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── invitation card ──────────────────────────────────────────────────────────

  Widget _buildCard(Map<String, dynamic> inv) {
    final status = inv['status'] as String;
    final isPending = status == 'pending';

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
            // ── Header: employer + status ──
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    (inv['employerName'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
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
                              inv['employerName'],
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (inv['employerVerified'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 13, color: AppColors.success),
                          ],
                        ],
                      ),
                      Text(inv['receivedDate'],
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.neutral400)),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Job info ──
            Text(inv['jobTitle'],
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 6),

            // Budget + location
            Row(
              children: [
                Text(inv['jobBudget'],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.neutral400),
                const SizedBox(width: 3),
                Text(inv['jobLocation'],
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral500)),
              ],
            ),
            const SizedBox(height: 8),

            // Description preview
            Text(
              inv['jobDescription'],
              style: const TextStyle(
                  fontSize: 13, color: AppColors.neutral600, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Action buttons (pending only) ──
            if (isPending) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // View job details
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/job-details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('View Job'),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Decline
                  ElevatedButton(
                    onPressed: () => _confirmDecline(inv),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.neutral200,
                      foregroundColor: AppColors.neutral700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),

                  // Accept
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAccept(inv),
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
                ],
              ),
            ],

            // ── Message button if accepted ──
            if (status == 'accepted') ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'name': inv['employerName'],
                      'jobTitle': inv['jobTitle'],
                      'jobLocation': inv['jobLocation'],
                      'jobSalary': inv['jobBudget'],
                      'isVerified': inv['employerVerified'],
                      'isOnline': false,
                      'otherRole': 'employer',
                    },
                  ),
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
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

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
      default:
        color = AppColors.neutral400;
        label = 'Declined';
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

  void _confirmAccept(Map<String, dynamic> inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Invitation?'),
        content: Text(
            'Accept the invitation for "${inv['jobTitle']}"? You\'ll be able to message the employer after accepting.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => inv['status'] = 'accepted');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Invitation accepted!')),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: {
                            'name': inv['employerName'],
                            'jobTitle': inv['jobTitle'],
                            'jobLocation': inv['jobLocation'],
                            'jobSalary': inv['jobBudget'],
                            'isVerified': inv['employerVerified'],
                            'isOnline': false,
                            'otherRole': 'employer',
                          },
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Message',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
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

  void _confirmDecline(Map<String, dynamic> inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Invitation?'),
        content: Text('Decline the invitation for "${inv['jobTitle']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => inv['status'] = 'declined');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation declined')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neutral600),
            child: const Text('Decline',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
