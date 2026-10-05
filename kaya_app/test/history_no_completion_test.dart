import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/active_screen.dart';
import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    A job that is over does not offer to be completed.

    Reported from the app: "why did you put mark as complete in the history".

    The employer's card asked whether the *hire* was finished and never
    whether the *job* was. History lists an employer's jobs that are not open
    or running - completed, closed, expired, flagged - and a job can be closed
    by hand or swept past its end date while still carrying an accepted hire
    nobody ever confirmed. Those rows drew Mark as Complete, and pressing it
    could only fail: JobCompletionService returns early for a job that is
    completed, closed or expired.

    So the control was inert, which this project bans outright - and the
    failure was silent, which is worse than a refusal.
*/
void main() {
  /// An employer's job with an accepted hire on it, at whatever job status.
  Map<String, dynamic> jobWithHire(String jobStatus) => {
        'id': 41,
        'title': 'Repaint a steel gate',
        'status': jobStatus,
        'city': 'Urdaneta City, Pangasinan',
        'budget_min': 900,
        'budget_max': 1200,
        'start_date': '2026-09-01',
        'end_date': '2026-09-02',
        'application_count': 1,
        'hire': {
          // Never confirmed by either side - the state that produced the bug.
          'application_id': 77,
          'worker_id': 8,
          'worker_name': 'Mang Tonyo',
          'status': 'accepted',
          'employer_completed_at': null,
          'worker_completed_at': null,
          'i_reviewed_them': false,
          'conversation_id': 12,
        },
      };

  Widget screen(Map<String, dynamic> job, {bool active = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()
            ..reconcile(hasWorker: false, hasEmployer: true),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(
          value: ApplicationProvider()..seedApplications([]),
        ),
        ChangeNotifierProvider<InvitationProvider>.value(
          value: InvitationProvider()..seedInvitations([]),
        ),
        ChangeNotifierProvider<JobProvider>.value(
          value: JobProvider()..seedMyJobs([job]),
        ),
      ],
      child: MaterialApp(
          home: active ? const ActiveScreen() : const ApplicationsScreen()),
    );
  }

  Future<void> render(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final over in <String>['closed', 'expired', 'completed']) {
    testWidgets('a $over job does not offer Mark as Complete', (tester) async {
      await render(tester, screen(jobWithHire(over)));

      // The row has to be on screen, or this passes over a blank History tab
      // and proves nothing.
      expect(
        find.textContaining('Repaint a steel gate'),
        findsWidgets,
        reason: 'the History row never rendered, so nothing was checked',
      );

      expect(
        find.textContaining('Mark as Complete'),
        findsNothing,
        reason: 'a $over job cannot be completed - the server refuses it, so '
            'the button could only ever fail silently',
      );
    });
  }

  testWidgets('a running job still offers it', (tester) async {
    /*
        The other half. Tightening the rule is only correct if it leaves the
        live case alone - otherwise the fix for a dead button is a missing
        one.
    */
    await render(tester, screen(jobWithHire('in_progress'), active: true));

    expect(find.textContaining('Mark as Complete'), findsWidgets);
  });
}
