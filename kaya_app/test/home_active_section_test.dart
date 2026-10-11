import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/jobs/widgets/active_section.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    The Active section on home: the worker's hired jobs, with Mark as
    complete and Review on the card. Not pending applications, which are
    nothing yet, and not the employer's running posts, which are My Jobs'
    Active tab and were the same job shown twice.
*/
void main() {
  Map<String, dynamic> hire(int id, String title) => {
        'id': id,
        'status': 'accepted',
        'worker_completed_at': null,
        'employer_completed_at': null,
        'job': {
          'id': id + 100,
          'title': title,
          'company': 'Villanueva Hardware',
          'status': 'in_progress',
          'start_date': '2026-09-01',
          'end_date': '2026-09-02',
        },
      };

  Map<String, dynamic> post(int id, String title, {bool live = true}) => {
        'id': id,
        'title': title,
        'status': 'open',
        'is_live': live,
        'application_count': 0,
        'hire': null,
      };

  Widget host({
    bool worker = true,
    bool employer = false,
    List<Map<String, dynamic>> applications = const [],
    List<Map<String, dynamic>> jobs = const [],
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()
            ..reconcile(hasWorker: worker, hasEmployer: employer),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(
          value: ApplicationProvider()..seedApplications(applications),
        ),
        ChangeNotifierProvider<JobProvider>.value(
          value: JobProvider()..seedMyJobs(jobs),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveSection(onChanged: () async {}),
          ),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  testWidgets('a hired worker sees the job, with Mark as Complete',
      (tester) async {
    await pump(tester, host(applications: [hire(5, 'Tile setter for a bathroom')]));

    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Tile setter for a bathroom'), findsWidgets);
    expect(find.textContaining('Mark as Complete'), findsOneWidget);
  });

  testWidgets('a pending application is not active work', (tester) async {
    await pump(
      tester,
      host(applications: [
        {
          'id': 6,
          'status': 'pending',
          'job': {'id': 9, 'title': 'Roof leak repair'},
        },
      ]),
    );

    expect(find.textContaining('Roof leak repair'), findsNothing);
    expect(find.text('Active'), findsNothing);
  });

  /*
      A running post lives in My Jobs, under its own Active tab. Repeating it
      here put the same job on screen twice, which was reported.
  */
  testWidgets('an employer\'s running post is not repeated here', (tester) async {
    await pump(
      tester,
      host(worker: false, employer: true, jobs: [post(1, 'Repaint a steel gate')]),
    );

    expect(find.textContaining('Repaint a steel gate'), findsNothing);
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('a post past its date is not active', (tester) async {
    await pump(
      tester,
      host(
        worker: false,
        employer: true,
        jobs: [post(1, 'Repaint a steel gate', live: false)],
      ),
    );

    expect(find.textContaining('Repaint a steel gate'), findsNothing);
  });

  /*
      A long list stays two cards tall: the rest are behind See all, not
      stacked down the home screen.
  */
  testWidgets('four items: two cards and See all', (tester) async {
    await pump(
      tester,
      host(applications: [for (var i = 1; i <= 4; i++) hire(i, 'Job number $i')]),
    );

    expect(find.textContaining('Job number 2'), findsWidgets);
    expect(find.textContaining('Job number 3'), findsNothing);
    expect(find.text('See all 4'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
      findsNothing,
    );
  });

  testWidgets('two items: both shown, no See all', (tester) async {
    await pump(
      tester,
      host(applications: [hire(1, 'Job number 1'), hire(2, 'Job number 2')]),
    );

    expect(find.textContaining('Job number 2'), findsWidgets);
    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('nothing active means nothing drawn', (tester) async {
    await pump(tester, host());

    expect(find.text('Active'), findsNothing);
  });
}
