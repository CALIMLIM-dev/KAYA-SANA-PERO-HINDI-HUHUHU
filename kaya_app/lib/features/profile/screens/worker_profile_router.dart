import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'my_worker_profile_screen.dart';
import '../../worker/screens/worker_setup_flow_screen.dart';

/// Decides whether to show the worker profile or the flow that creates one.
///
/// - No profile → WorkerSetupFlowScreen
/// - A profile, finished or not → MyWorkerProfileScreen
///
/// Nothing is decided until /me has answered; see the note in build().
class WorkerProfileRouter extends StatelessWidget {
  const WorkerProfileRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, WorkerProfileProvider>(
      builder: (context, authProvider, workerProvider, _) {
        final workerProfileExists = authProvider.workerProfileExists;
        final workerSetupCompleted = authProvider.workerSetupCompleted;

        /*
            Nothing may be decided before /me answers.

            Every flag below reads `_user?['...'] ?? false`, so while the
            request is in flight they all say "no profile" — the same answer
            an account with genuinely no profile gives. Branching on that sent
            an established worker into the setup flow for as long as the
            request took, which on a good connection reads as a flash and on
            mobile data reads as having lost your profile.

            EmployerProfileRouter has always waited here. This is that rule,
            and the pair of them is asserted in navigation_flash_test.dart so
            the two sides cannot drift apart again.
        */
        if (!authProvider.hasFetchedMe) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // No worker profile exists → Show setup flow
        if (!workerProfileExists) {
          return const WorkerSetupFlowScreen();
        }

        /*
            A profile that exists is shown, finished or not.

            This used to send an incomplete profile back into the setup flow,
            and that was the wall the whole second-profile path kept hitting.
            worker_setup_completed is computed - location, category and one
            skill - so any profile missing one of them was answered with the
            wizard again, every single time the screen was opened, with no way
            past it but to walk the seven pages.

            The profile screen is the better answer even for a half-made
            profile: skills, experience, certifications, licences, the rate and
            the photo all have their own edit controls there, and the
            completeness prompt says which one is worth doing next. The wizard
            stays for the case it was built for - an account with no profile at
            all, which has nothing to show.

            resumeStep therefore no longer has a caller. It is kept because the
            flow still accepts one and a later screen may want to deep-link
            into a step.
        */
        if (!workerSetupCompleted &&
            workerProvider.isLoading &&
            workerProvider.location == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const MyWorkerProfileScreen();
      },
    );
  }
}
