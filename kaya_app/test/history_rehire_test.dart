import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    Working together again starts from History.

    There used to be a separate "worked with before" screen behind an icon in
    the My Jobs app bar. It listed the same people whose finished jobs are in
    History, so the job somebody remembered and the person they wanted to hire
    again were in two different places. Both sides now act from the finished
    job itself.

    The worker's half matters more than it looks: the conversation is hidden
    once a job completes, so without this a worker who did well for somebody
    had no way back to them at all.
*/
void main() {
  Map<String, dynamic> finishedApplication() => {
        'id': 91,
        'status': 'completed',
        'conversation_id': 12,
        'worker_completed_at': '2026-09-01T08:00:00Z',
        'employer_completed_at': '2026-09-01T09:00:00Z',
        'i_reviewed_them': true,
        'they_reviewed_me': true,
        'job': {
          'id': 5,
          'title': 'Repainting of a three bedroom bungalow',
          'category': {'id': 3, 'name': 'Painting'},
          'city': 'Urdaneta City, Pangasinan',
          'budget_min': 900,
          'budget_max': 1200,
          'status': 'completed',
          'employer': {
            'id': 9,
            'name': 'Santiago Construction and General Services',
            'is_verified': true,
          },
        },
      };

  Map<String, dynamic> liveApplication() => {
        ...finishedApplication(),
        'id': 92,
        'status': 'accepted',
        'i_reviewed_them': false,
        'they_reviewed_me': false,
        'job': {
          ...finishedApplication()['job'] as Map<String, dynamic>,
          'status': 'in_progress',
        },
      };

  Widget screen(List<Map<String, dynamic>> applications) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AppModeProvider>.value(
            value: AppModeProvider()..reconcile(hasWorker: true, hasEmployer: false),
          ),
          ChangeNotifierProvider<ApplicationProvider>.value(
            value: ApplicationProvider()..seedApplications(applications),
          ),
          ChangeNotifierProvider<InvitationProvider>.value(
            value: InvitationProvider()..seedInvitations([]),
          ),
          ChangeNotifierProvider<JobProvider>.value(value: JobProvider()..seedMyJobs([])),
        ],
        child: const MaterialApp(home: ApplicationsScreen()),
      );

  Future<void> render(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// History is the second tab. The live work sits on the first.
  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.byType(Tab).last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a finished job offers the way back to that employer',
      (tester) async {
    await render(tester, screen([finishedApplication()]));
    await openHistory(tester);

    expect(find.text('Ask for work again'), findsWidgets,
        reason: 'the thread is hidden once the job is done, so History is the '
            'only route back to somebody you worked well for');
    expect(find.text('Message'), findsNothing,
        reason: 'there is no thread left to open on a finished job');
  });

  testWidgets('live work still offers the thread, not the detour',
      (tester) async {
    await render(tester, screen([liveApplication()]));

    expect(find.text('Message'), findsWidgets);
    expect(find.text('Ask for work again'), findsNothing);
  });
}
