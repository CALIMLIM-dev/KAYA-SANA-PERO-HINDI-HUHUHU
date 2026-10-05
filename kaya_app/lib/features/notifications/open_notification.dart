import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_mode.dart';
import '../../core/navigation/app_router.dart';
import '../../core/widgets/app_toast.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import 'notification_destination.dart';

/*
    Opens whatever a notification is about.

    One function for the three places a notification can be tapped: the
    list, the banner that slides in while the app is open, and the phone's
    notification shade. The banner and the shade had their own copy of the
    rules, and it had drifted: "a worker accepted your invitation" opened
    the employer's own public job advert from the banner, while the list
    opened the applicants; and an invitation opened the worker's invitations
    without switching a hybrid account to its worker side.

    Where to go comes from notificationDestination(); this only knows how to
    open it, and whether this account can.
*/
void openNotification(
  BuildContext context, {
  required String type,
  required String audience,
  String? referenceType,
  int? referenceId,
}) {
  final where = notificationDestination(
    type: type,
    audience: audience,
    referenceType: referenceType,
    referenceId: referenceId,
  );

  switch (where) {
    case NotificationDestination.applicants:
      if (!_allow(context, employerSide: true)) return;

      /*
          A notification outlives the applicant it announced.

          It stays in the list after the person withdraws, or after the
          employer accepts or declines them, and tapping it then opened an
          applicant list with nobody on it - which reads as the screen
          failing to load rather than as nothing being there.

          Only refused when the jobs list is actually loaded and says this
          job has nobody pending. With no data the tap goes through, because
          guessing "empty" from a list that was never fetched would block a
          real applicant.
      */
      if (type == 'application.received') {
        final jobs = context.read<JobProvider>().jobs;
        final job = jobs.where((j) => j['id'] == referenceId).firstOrNull;
        final pending = job?['pending_application_count'];

        if (job != null && pending is int && pending == 0) {
          AppToast.info(context,
              'Nobody is waiting on that job any more — they withdrew, or you already answered them.');
          return;
        }
      }

      AppRouter.push(context,
        AppRouter.viewApplicants,
        arguments: {'jobId': referenceId},
      );

    case NotificationDestination.manageJobs:
      if (!_allow(context, employerSide: true)) return;
      AppRouter.push(context, AppRouter.manageJobs);

    case NotificationDestination.jobDetails:
      if (referenceId != null) {
        AppRouter.push(context,
          AppRouter.jobDetails,
          arguments: {'jobId': referenceId},
        );
      }

    case NotificationDestination.active:
      AppRouter.push(context, AppRouter.active);

    case NotificationDestination.applications:
      if (!_allow(context, employerSide: false)) return;
      AppRouter.push(context, AppRouter.applications);

    case NotificationDestination.invitations:
      if (!_allow(context, employerSide: false)) return;
      AppRouter.push(context, '/my-invitations');

    case NotificationDestination.chat:
      AppRouter.push(context,
        AppRouter.chat,
        arguments: {'conversationId': referenceId},
      );

    case NotificationDestination.messages:
      AppRouter.push(context, AppRouter.messages);

    /*
        The public view of yourself, not the profile tab.

        Reviews are only drawn on the public profile - the page somebody
        else opens - so sending a review notification to the account's own
        profile screen landed on a page with no review on it at all.
    */
    case NotificationDestination.workerProfile:
      if (!_allow(context, employerSide: false)) return;

      final workerId = context.read<AuthProvider>().user?['id'];
      if (workerId == null) return;

      AppRouter.push(context,
        AppRouter.workerProfile,
        arguments: {'workerId': workerId},
      );

    case NotificationDestination.employerProfile:
      if (!_allow(context, employerSide: true)) return;

      final employerId = context.read<AuthProvider>().user?['id'];
      if (employerId == null) return;

      AppRouter.push(context,
        AppRouter.employerProfile,
        arguments: {'employerId': employerId},
      );

    /*
        Approved or rejected identity check, read from the notification.

        A rejection means send a better photo, so it opens the form; an
        approval has nothing to fill in, so it opens the profile where the
        badge is. Asking hasSubmittedVerification() instead answered a
        different question, about a different document, and sent a second
        rejection to the profile.
    */
    case NotificationDestination.verification:
      AppRouter.push(
        context,
        type == 'verification.rejected' ? '/verification' : AppRouter.profile,
      );

    case NotificationDestination.none:
      AppRouter.push(context, AppRouter.notifications);
  }
}

/*
    A notification is a route only if this account can actually open it.

    Nothing used to ask whether the person tapping had the profile the
    destination belongs to - so "someone applied to your job" sent whoever
    tapped it to an employer screen the server then refused.

    For a hybrid the answer is not to refuse but to follow: they hold both
    profiles, so switch to the side the notification belongs to and then go.
*/
bool _allow(BuildContext context, {required bool employerSide}) {
  final mode = context.read<AppModeProvider>();

  if (employerSide ? !mode.hasEmployerProfile : !mode.hasWorkerProfile) {
    AppToast.info(
      context,
      employerSide
          ? 'That is about a job post. Set up an employer profile to see applicants.'
          : 'That is about applying for work. Set up a worker profile to open it.',
    );
    return false;
  }

  final target = employerSide ? AppMode.employer : AppMode.worker;
  final showing = employerSide
      ? mode.effectiveMode.showsEmployerSide
      : mode.effectiveMode.showsWorkerSide;

  if (!showing && mode.canActivate(target)) mode.setMode(target);

  return true;
}
