import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/invitation_provider.dart';
import '../widgets/invitation_card.dart';

/// My Invitations — the jobs employers have invited this worker to.
///
/// The ones waiting on an answer first, then everything already answered or
/// closed, each on the same card My Activity's Invited sheet uses.
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
          final invitations = provider.invitations;

          if (provider.isLoading && invitations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only when there is nothing to show. A list already on screen
          // stays there through a failed refresh or a refused Accept.
          if (provider.loadError != null && invitations.isEmpty) {
            return _errorState(provider.loadError!);
          }

          if (invitations.isEmpty) return _buildEmptyState();

          final waiting = invitations.where((i) => i['status'] == 'pending').toList();
          final earlier = invitations.where((i) => i['status'] != 'pending').toList();

          return RefreshIndicator(
            onRefresh: provider.fetchMyInvitations,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (waiting.isNotEmpty) ...[
                  _heading('Waiting for your answer', waiting.length),
                  for (final i in waiting) InvitationCard(key: ValueKey(i['id']), invitation: i),
                ],
                if (earlier.isNotEmpty) ...[
                  if (waiting.isNotEmpty) const SizedBox(height: 8),
                  _heading('Earlier', earlier.length),
                  for (final i in earlier) InvitationCard(key: ValueKey(i['id']), invitation: i),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heading(String text, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          '$text ($count)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral600,
          ),
        ),
      );

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.neutral400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<InvitationProvider>().fetchMyInvitations(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

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
              child: const Icon(Icons.mail_outline, size: 40, color: AppColors.primary),
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
              style: TextStyle(fontSize: 14, color: AppColors.neutral600, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
