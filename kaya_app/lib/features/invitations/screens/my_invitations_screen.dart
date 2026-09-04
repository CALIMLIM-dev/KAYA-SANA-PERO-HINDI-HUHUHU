import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/invitation_provider.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verify_gate.dart';

/// My Invitations Screen — Worker sees job invitations from employers.
/// Backed by GET /my-invitations; Accept/Decline call the real endpoints.
class MyInvitationsScreen extends StatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  State<MyInvitationsScreen> createState() => _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends State<MyInvitationsScreen>
    with RealtimeRefresh {
  @override
  List<String> get refreshOn => const ['invitation.'];

  @override
  void onRealtimeRefresh() =>
      context.read<InvitationProvider>().fetchMyInvitations();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InvitationProvider>().fetchMyInvitations();
      bindRealtimeRefresh();
    });
  }

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
      body: Consumer<InvitationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.invitations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.neutral400),
                    const SizedBox(height: 12),
                    Text(provider.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<InvitationProvider>().fetchMyInvitations(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final invitations = provider.invitations;

          return invitations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => provider.fetchMyInvitations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: invitations.length,
                    itemBuilder: (_, i) => _buildCard(invitations[i]),
                  ),
                );
        },
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
    final status = (inv['status'] ?? 'pending').toString();
    final isPending = status == 'pending';

    final job = inv['job'] as Map<String, dynamic>?;
    final employer = inv['employer'] as Map<String, dynamic>?;

    final jobId = job?['id'] as int?;
    final jobTitle = (job?['title'] ?? 'Job').toString();
    final jobLocation = (job?['city'] ?? job?['location'] ?? '').toString();
    final jobBudget = _formatSalary(job?['budget_min'], job?['budget_max']);
    final employerName = (employer?['name'] ?? 'Employer').toString();
    final employerVerified = (employer?['is_verified'] as bool?) ?? false;

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
                    employerName.isNotEmpty ? employerName[0].toUpperCase() : '?',
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
                              employerName,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (employerVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 13, color: AppColors.success),
                          ],
                        ],
                      ),
                      if (inv['created_at'] != null)
                        Text(_timeAgo(inv['created_at'].toString()),
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
            Text(jobTitle,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 6),

            Row(
              children: [
                Text(jobBudget,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                if (jobLocation.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.neutral400),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(jobLocation,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),

            // ── Action buttons (pending only) ──
            if (isPending) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: jobId == null
                          ? null
                          : () => Navigator.pushNamed(context, '/job-details',
                              arguments: {'jobId': jobId}),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('View Job'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _confirmDecline(inv),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neutral200,
                      foregroundColor: AppColors.neutral700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
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
                            fontSize: 13.5, fontWeight: FontWeight.w600),
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
                  // The invitation row itself carries no conversation_id — the
                  // conversation lives on Messages, created when accepted.
                  onPressed: () => MainNavigation.openMessages(context),
                  icon: const Icon(Icons.message_outlined, size: 16),
                  label: const Text('Message Employer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSalary(Object? min, Object? max) {
    double? asDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    final minV = asDouble(min);
    final maxV = asDouble(max);
    if (minV == null && maxV == null) return 'Negotiable';
    if (minV != null && maxV != null && maxV != minV) {
      return '₱${minV.toStringAsFixed(0)}-${maxV.toStringAsFixed(0)}';
    }
    return '₱${(minV ?? maxV)!.toStringAsFixed(0)}';
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
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
    final job = inv['job'] as Map<String, dynamic>?;
    final jobTitle = (job?['title'] ?? 'this job').toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Invitation?'),
        content: Text(
            'Accept the invitation for "$jobTitle"? You\'ll be able to message the employer after accepting.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Same gate as everywhere else that commits or spends: an
              // account under review is told so rather than refused blankly.
              if (!await ensureVerified(context,
                  action: 'accept an invitation')) {
                return;
              }
              if (!mounted) return;
              final conversationId =
                  await context.read<InvitationProvider>().accept(inv['id'] as int);
              if (!mounted) return;
              final employer = inv['employer'] as Map<String, dynamic>?;

              if (conversationId == null) {
                AppToast.error(
                  context,
                  context.read<InvitationProvider>().errorMessage ??
                      'Failed to accept invitation',
                );
                return;
              }

              AppToast.show(
                context,
                'Invitation accepted!',
                type: ToastType.success,
                duration: const Duration(seconds: 4),
                actionLabel: 'Message',
                onAction: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {
                    'conversationId': conversationId,
                    'name': employer?['name'] ?? 'Employer',
                    'jobTitle': jobTitle,
                    'jobId': job?['id'],
                    'otherUserId': employer?['id'],
                    'isVerified': employer?['is_verified'] ?? false,
                    'otherRole': 'employer',
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDecline(Map<String, dynamic> inv) {
    final job = inv['job'] as Map<String, dynamic>?;
    final jobTitle = (job?['title'] ?? 'this job').toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Invitation?'),
        content: Text('Decline the invitation for "$jobTitle"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<InvitationProvider>().decline(inv['id'] as int);
              if (!mounted) return;
              AppToast.info(context, success
                      ? 'Invitation declined'
                      : context.read<InvitationProvider>().errorMessage ??
                          'Failed to decline invitation');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neutral600),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
