import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/jobs/widgets/work_in_progress_section.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    The Active section on home is My Activity's Active tab, moved.

    Reported: "the work in progress is not here even though there is a job -
    I said move the ACTIVE there." The first version listed only hires that
    already existed, so an open post with nobody hired, and an application
    still waiting for a reply, both showed nothing. Both are active work.
*/
void main() {
  Widget host({
    List<Map<String, dynamic>> applications = const [],
    List<Map<String, dynamic>> jobs = const [],
  }) {
    return MultiProvider(
      providers: [
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
            child: WorkInProgressSection(onChanged: () async {}),
          ),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  testWidgets('an open post with nobody hired yet is shown', (tester) async {
    await pump(
      tester,
      host(jobs: [
        {
          'id': 1,
          'title': 'Repaint a steel gate',
          'status': 'open',
          'is_live': true,
          'application_count': 0,
          'hire': null,
        },
      ]),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Repaint a steel gate'), findsOneWidget);
    expect(find.text('No applicants yet'), findsOneWidget);
    // Nothing to complete, so no button.
    expect(find.textContaining('complete'), findsNothing);
  });

  testWidgets('applicants waiting are counted', (tester) async {
    await pump(
      tester,
      host(jobs: [
        {
          'id': 1,
          'title': 'Repaint a steel gate',
          'status': 'open',
          'is_live': true,
          'application_count': 3,
          'hire': null,
        },
      ]),
    );

    expect(find.text('3 applicants waiting on you'), findsOneWidget);
  });

  testWidgets('an application still waiting for a reply is shown',
      (tester) async {
    await pump(
      tester,
      host(applications: [
        {
          'id': 5,
          'status': 'pending',
          'job': {'id': 9, 'title': 'Tile setter for a bathroom'},
        },
      ]),
    );

    expect(find.text('Tile setter for a bathroom'), findsOneWidget);
    expect(find.text('Waiting for a reply'), findsOneWidget);
  });

  testWidgets('a live hire offers Mark as complete, from either side',
      (tester) async {
    await pump(
      tester,
      host(
        applications: [
          {
            'id': 5,
            'status': 'accepted',
            'worker_completed_at': null,
            'employer_completed_at': null,
            'job': {
              'id': 9,
              'title': 'Tile setter for a bathroom',
              'status': 'in_progress',
              'start_date': '2026-09-01',
              'end_date': '2026-09-02',
            },
          },
        ],
        jobs: [
          {
            'id': 1,
            'title': 'Repaint a steel gate',
            'status': 'in_progress',
            'is_live': true,
            'start_date': '2026-09-01',
            'end_date': '2026-09-02',
            'hire': {
              'application_id': 77,
              'status': 'accepted',
              'worker_name': 'Mang Tonyo',
              'employer_completed_at': null,
              'worker_completed_at': null,
            },
          },
        ],
      ),
    );

    // One button per live hire: the worker's and the employer's.
    expect(find.text('Mark as complete'), findsNWidgets(2));
  });

  testWidgets('nothing active means nothing drawn', (tester) async {
    await pump(tester, host());

    expect(find.text('Active'), findsNothing);
  });
}
