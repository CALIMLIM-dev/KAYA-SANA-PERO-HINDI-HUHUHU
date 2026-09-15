import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_mode_provider.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/credits_provider.dart';
import '../../providers/employer_profile_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/profile_view_provider.dart';
import '../../providers/worker_profile_provider.dart';

/*
    Ends the session on this phone and lands on the login screen.

    Every provider that holds one account's data is cleared, so the next
    person to sign in on the handset does not inherit a balance, an inbox
    or a list of applicants that is not theirs. Reference data (categories,
    the skill catalogue) is the same for everyone and is left alone.

    Lived inline in the profile screen's Logout button. Deleting an account
    ends the session the same way, so it moved here.
*/
Future<void> endSession(BuildContext context) async {
  // Resolved before the await: the context may be gone by the time
  // logout returns.
  final auth = context.read<AuthProvider>();
  final appMode = context.read<AppModeProvider>();
  final notifications = context.read<NotificationProvider>();
  final profileViews = context.read<ProfileViewProvider>();
  final credits = context.read<CreditsProvider>();
  final jobs = context.read<JobProvider>();
  final applications = context.read<ApplicationProvider>();
  final invitations = context.read<InvitationProvider>();
  final messaging = context.read<MessagingProvider>();
  final workerProfile = context.read<WorkerProfileProvider>();
  final employerProfile = context.read<EmployerProfileProvider>();
  final community = context.read<CommunityProvider>();

  await auth.logout();
  await appMode.clear();

  notifications.clear();
  profileViews.clear();
  credits.clear();
  jobs.clear();
  applications.clear();
  invitations.clear();
  messaging.clear();
  workerProfile.clear();
  employerProfile.clear();
  community.clear();

  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}
