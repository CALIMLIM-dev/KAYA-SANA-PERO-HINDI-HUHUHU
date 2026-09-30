import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/skill_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import 'add_skills_screen.dart';

/*
    Adding the second profile to an account that already has one.

    The setup flows exist to onboard somebody the app knows nothing about: they
    ask for a name, a town, a photo and a government ID because none of them
    are on record yet. An account that already holds a profile is the opposite
    case - all four are on record, and asking again is how one person ended up
    with two pictures of themselves and two spellings of their own town.

    So each direction asks only for what it genuinely cannot inherit, and the
    server builds the rest from the account:

      employer -> worker   one question, the trade. browse() filters on the
                           category and nothing on the account can supply it.
      worker   -> employer  no question at all. The only two required fields
                           are the type and the location, and both are already
                           decided - an account that looks for work can only be
                           an individual employer.

    Both share the dialog and the held screen, so the two directions cannot
    drift into describing the same rule differently.
*/
class SecondProfileFlow {
  const SecondProfileFlow._();

  /*
      Adds the worker side. Returns true when a profile was created.

      Every exit that is not a created profile leaves the account exactly as it
      was: backing out of the dialog, backing out of the skills picker, and a
      server refusal all return false and write nothing.
  */
  static Future<bool> addWorker(BuildContext context) async {
    final agreed = await _confirm(
      context,
      title: 'Add a Worker Profile',
      detail: 'Add your trade and skills to finish.',
    );

    if (agreed != true || !context.mounted) return false;

    /*
        The trade, which is the only thing this direction asks for.

        Reusing the screen the setup flow and the profile both use rather than
        writing a third skills picker: it already lists the categories, loads
        the skills under one, and allows a trade the catalogue has never seen.
    */
    final skills = await Navigator.push<List<SkillModel>>(
      context,
      MaterialPageRoute(builder: (_) => const AddSkillsScreen()),
    );

    if (skills == null || skills.isEmpty || !context.mounted) return false;

    /*
        The trade the profile is filed under.

        Taken from the skills themselves rather than asked for separately -
        picking a category is how the skills were chosen in the first place, so
        asking again would be asking the same question twice. The most common
        one wins, because a worker who picked four carpentry skills and one
        plumbing one is a carpenter.
    */
    final categoryId = dominantCategory(skills);

    if (categoryId == null) {
      AppToast.error(
        context,
        'Pick a category for your skills so employers can find you.',
      );
      return false;
    }

    return _create(
      context,
      message: 'Setting up your worker profile',
      destination: AppRouter.myWorkerProfile,
      fallback: 'Could not create your worker profile.',
      run: () => context.read<WorkerProfileProvider>().createFromAccount(
            categoryId: categoryId,
            skills: skills,
          ),
      reason: () => context.read<WorkerProfileProvider>().errorMessage,
    );
  }

  /*
      Adds the employer side, which asks nothing.

      The type cannot be chosen - an account with a worker profile can only be
      an individual employer, and the server refuses a company on one in both
      directions - and the location comes from the profile the account already
      has. There is no third thing, so the dialog is the whole of it.
  */
  static Future<bool> addEmployer(BuildContext context) async {
    final agreed = await _confirm(
      context,
      title: 'Add an Employer Profile',
      detail: '',
    );

    if (agreed != true || !context.mounted) return false;

    return _create(
      context,
      message: 'Setting up your employer profile',
      destination: AppRouter.myEmployerProfile,
      fallback: 'Could not create your employer profile.',
      run: () => context.read<EmployerProfileProvider>().createFromAccount(),
      reason: () => context.read<EmployerProfileProvider>().errorMessage,
    );
  }

  /*
      One dialog for both directions.

      [detail] is the only part that differs, and it is the sentence that says
      what this particular side still needs. Everything above it is the rule
      itself, which is the same rule whichever way round it is read.
  */
  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String detail,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
                The reason this is one tap instead of several pages.

                Without it the flow reads as though it skipped something it
                should have asked, which is how a shortcut gets reported as a
                bug.
            */
            Text(
              'Your name, photo, location and verification carry over.'
              '${detail.isEmpty ? '' : ' '}$detail',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.neutral600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.neutral600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Continue',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
      The trade most of the chosen skills belong to.

      Null when every skill is one the catalogue has never seen, which have no
      category to count. The caller asks rather than guessing: a profile filed
      under the wrong trade is worse than one more question, because browse()
      filters on it.
  */
  @visibleForTesting
  static int? dominantCategory(List<SkillModel> skills) {
    final counts = <int, int>{};

    for (final skill in skills) {
      if (skill.categoryId > 0) {
        counts[skill.categoryId] = (counts[skill.categoryId] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return null;

    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /*
      Creates the profile behind a held screen.

      Held for a reason beyond looking busy: the moment /me reports the new
      profile, AppModeProvider re-derives the account as hybrid and the home
      screen changes shape underneath. Without something covering that, one
      side's home visibly becomes the unified home mid-request.
  */
  static Future<bool> _create(
    BuildContext context, {
    required String message,
    required String destination,
    required String fallback,
    required Future<bool> Function() run,
    required String? Function() reason,
  }) async {
    final navigator = Navigator.of(context);
    final auth = context.read<AuthProvider>();

    // Its own route, so nothing behind it can be rebuilt into view while the
    // two requests run.
    navigator.push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, _, _) => SecondProfilePreparingScreen(message: message),
      ),
    );

    final created = await run();

    if (created) {
      // Only now, so the flags and the home screen change behind the held
      // screen rather than in front of it.
      await auth.fetchMe();
    }

    if (!navigator.mounted) return created;

    if (!created) {
      // Back to where they were, with the reason. Nothing was written.
      navigator.pop();

      if (context.mounted) {
        AppToast.error(context, reason() ?? fallback);
      }

      return false;
    }

    /*
        Onto the profile, with the flow removed behind it.

        pushNamedAndRemoveUntil rather than a pop: the held screen, any picker
        and the row that started this are all gone, so the back gesture cannot
        walk into a flow that has already finished.
    */
    navigator.pushNamedAndRemoveUntil(destination, (route) => route.isFirst);

    return true;
  }
}

/*
    The held screen while the profile is made.

    Carries the mark rather than a bare spinner, because this is the one moment
    in the app where the account itself is changing and a plain indicator over
    a white page reads as a stall.
*/
class SecondProfilePreparingScreen extends StatelessWidget {
  const SecondProfilePreparingScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Two requests are in flight and the account is mid-change. There is
      // nothing useful a back gesture could do here.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will only take a moment.',
                style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
