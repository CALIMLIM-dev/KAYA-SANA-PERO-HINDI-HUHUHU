import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../employer/screens/setup_employer_profile_screen.dart';
import 'my_employer_profile_screen.dart';

/// One entry point for the employer side of an account.
///
/// Decides between "set this up" and "here it is" so no caller has to. That
/// decision used to live at the call sites — the profile menu checked
/// `employerProfileExists` and picked a route itself — which meant every new
/// place that linked to the employer profile had to remember to repeat the
/// check, and anything that forgot sent a user with no profile to a screen
/// built to display one.
///
/// Mirrors WorkerProfileRouter deliberately. A hybrid account has two of these
/// and they should behave identically; the moment one grows a rule the other
/// lacks is the moment a user finds a dead end on one side only.
class EmployerProfileRouter extends StatefulWidget {
  const EmployerProfileRouter({super.key});

  @override
  State<EmployerProfileRouter> createState() => _EmployerProfileRouterState();
}

class _EmployerProfileRouterState extends State<EmployerProfileRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<EmployerProfileProvider>();
      // Only once. The provider is app-scoped, so re-fetching on every visit
      // would flash a spinner over a profile already in memory.
      if (!provider.hasFetchedOnce) provider.fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<EmployerProfileProvider>();

    // /me is the authority on existence — it is computed server-side from the
    // profile row, and it is already loaded before this screen can be reached.
    // The provider is only consulted once it has actually fetched, so a cold
    // open doesn't briefly decide "no profile" and throw the user into setup.
    final exists = auth.employerProfileExists ||
        (provider.hasFetchedOnce && provider.hasProfile);

    if (!provider.hasFetchedOnce && !auth.employerProfileExists) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!exists) {
      return const SetupEmployerProfileScreen();
    }

    /*
        A row is not a profile.

        This only asked whether an employer profile existed, and a row gets
        created the moment somebody starts setting one up. So tapping Employer
        Profile from the menu after an abandoned attempt opened the display
        screen with nothing in it — no name, no location, and no way to fill
        them in. It looked like a broken profile rather than an unfinished one.

        The worker router has always had this branch. This is the same rule:
        exists but not finished means go and finish it.
    */
    if (!auth.employerSetupCompleted) {
      return const SetupEmployerProfileScreen();
    }

    return const MyEmployerProfileScreen();
  }
}
