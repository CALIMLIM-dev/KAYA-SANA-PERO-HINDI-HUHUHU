import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../core/constants/app_colors.dart';
import 'my_worker_profile_screen.dart';
import '../../worker/screens/worker_setup_flow_screen.dart';

/// Pure Router for Worker Profile
/// 
/// Routes based on worker_profile_exists and worker_setup_completed from AuthProvider
/// 
/// Logic:
/// - No profile → WorkerSetupFlowScreen (step 1)
/// - Profile exists but incomplete → Resume setup at appropriate step
/// - Profile complete → MyWorkerProfileScreen
class WorkerProfileRouter extends StatelessWidget {
  const WorkerProfileRouter({super.key});

  /// Determine which step to resume based on existing profile data
  /// 
  /// Steps:
  /// 0. Location (required)
  /// 1. Category + Skills (required)
  /// 2. Experience (optional)
  /// 3. Certifications (optional)
  /// 4. Licenses (optional)
  /// 5. Profile Photo (optional)
  /// 6. Verification (optional)
  int _getResumeStep(WorkerProfileProvider provider) {
    // If no location, start at step 0
    if (provider.location == null || provider.location!.isEmpty) {
      return 0;
    }
    
    // If no skills, go to step 1 (category + skills)
    if (provider.skills.isEmpty) {
      return 1;
    }
    
    // If no experience, go to step 2
    if (provider.experiencesNew.isEmpty) {
      return 2;
    }
    
    // If no certifications, go to step 3
    if (provider.certifications.isEmpty) {
      return 3;
    }
    
    // If no licenses, go to step 4
    if (provider.licenses.isEmpty) {
      return 4;
    }
    
    // If no photo, go to step 5
    if (provider.profilePhotoPath == null || provider.profilePhotoPath!.isEmpty) {
      return 5;
    }
    
    // Otherwise, go to verification step 6
    return 6;
  }

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

        // Profile exists but setup incomplete → Resume setup
        if (!workerSetupCompleted) {
          // Show loading while fetching profile data to determine resume step
          if (workerProvider.isLoading && workerProvider.location == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final resumeStep = _getResumeStep(workerProvider);
          return WorkerSetupFlowScreen(resumeStep: resumeStep);
        }

        // Profile complete → Show permanent profile screen
        return const MyWorkerProfileScreen();
      },
    );
  }
}
