import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_router.dart';
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
import '../../providers/schedule_provider.dart';
import '../../providers/verification_provider.dart';
import '../../providers/worker_browse_provider.dart';
import '../../providers/worker_profile_provider.dart';

/*
    Everything one account left in memory, cleared.

    A session ends two ways - the Log out button, or a token the server
    stops accepting - and each kept its own list of what to clear. The
    second one cleared four providers and left the rest, so the next person
    to sign in on the phone could open on somebody else's lists. One list
    now, used by both. Reference data (categories, the skill catalogue) is
    the same for everyone and is left alone.

    The providers are read straight away, while the context is live, and
    cleared when the returned function is called - after whatever await
    comes between.
*/
Future<void> Function() sessionClearer(BuildContext context) {
  final appMode = context.read<AppModeProvider>();
  final clears = <VoidCallback>[
    context.read<NotificationProvider>().clear,
    context.read<ProfileViewProvider>().clear,
    context.read<CreditsProvider>().clear,
    context.read<JobProvider>().clear,
    context.read<ApplicationProvider>().clear,
    context.read<InvitationProvider>().clear,
    context.read<MessagingProvider>().clear,
    context.read<ScheduleProvider>().clear,
    context.read<WorkerProfileProvider>().clear,
    context.read<EmployerProfileProvider>().clear,
    context.read<WorkerBrowseProvider>().clear,
    context.read<VerificationProvider>().clear,
    context.read<CommunityProvider>().clear,
  ];

  return () async {
    await appMode.clear();
    for (final clear in clears) {
      clear();
    }
  };
}

/*
    Ends the session on this phone and lands on the login screen.

    Lived inline in the profile screen's Logout button. Deleting an account
    ends the session the same way, so it moved here.
*/
Future<void> endSession(BuildContext context) async {
  // Resolved before the await: the context may be gone by the time
  // logout returns.
  final auth = context.read<AuthProvider>();
  final clear = sessionClearer(context);

  await auth.logout();
  await clear();

  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, AppRouter.login, (route) => false);
  }
}
