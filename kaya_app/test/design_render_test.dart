import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/core/widgets/kaya_mark.dart';
import 'package:kaya_app/features/employer/screens/matched_workers_screen.dart';
import 'package:kaya_app/features/jobs/widgets/active_section.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';

import 'support/render_harness.dart';

/*
    The launch mark, the Active panel on home and the matched-workers pop-up,
    rendered with real content so a change to any of them is seen.

    Run: flutter test test/design_render_test.dart --update-goldens
*/
void main() {
  Future<void> size(WidgetTester tester, double height) async {
    RenderHarness.stubPlatformChannels(tester);
    await RenderHarness.loadFonts(tester);
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('launch mark, fully drawn', (tester) async {
    await size(tester, 2400);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(backgroundColor: Colors.white, body: Center(child: KayaLaunch())),
    ));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('KAYA'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/kaya_launch.png'));
  });

  testWidgets('home Active panel, both sides', (tester) async {
    await size(tester, 1500);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()..reconcile(hasWorker: true, hasEmployer: true),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(
          value: ApplicationProvider()
            ..seedApplications([
              {
                'id': 1,
                'status': 'accepted',
                'worker_completed_at': null,
                'employer_completed_at': null,
                'job': {
                  'id': 101,
                  'title': 'Repainting of a three bedroom bungalow',
                  'company': 'Santiago Construction and General Services',
                  'status': 'in_progress',
                  'budget_min': 800,
                  'budget_max': 1200,
                  'budget_period': 'daily',
                  'start_date': '2026-09-01',
                  'end_date': '2026-09-02',
                },
              },
            ]),
        ),
        ChangeNotifierProvider<JobProvider>.value(
          value: JobProvider()
            ..seedMyJobs([
              {
                'id': 7,
                'title': 'Aircon cleaning, two split units',
                'status': 'open',
                'is_live': true,
                'application_count': 3,
                'budget_min': 1500,
                'budget_period': 'project',
                'hire': null,
              },
            ]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24),
            child: ActiveSection(onChanged: () async {}),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('Repainting'), findsWidgets);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_active_panel.png'));
  });

  testWidgets('matched workers pop-up', (tester) async {
    await size(tester, 2400);
    final browse = WorkerBrowseProvider()
      ..seedMatches([
        {
          'user_id': 11,
          'name': 'Maria Clara Dela Cruz-Santiago',
          'category': 'Painting',
          'distance_label': 'About 3 km away',
          'skills': ['Interior painting', 'Exterior painting'],
          'matched_skills': ['interior painting'],
          'required_count': 2,
          'matched_count': 1,
          'match_tier': 2,
          'same_trade': true,
          'verification_state': 'verified',
          'criteria': [
            {'key': 'rate', 'met': true, 'text': 'Asks ₱900/day, within budget'},
            {'key': 'days', 'met': true, 'text': 'Works on the job dates'},
            {'key': 'travel', 'met': false, 'text': 'Outside their 5 km travel range'},
          ],
        },
        {
          'user_id': 12,
          'name': 'Jose Rizal Bautista',
          'category': 'Painting',
          'distance_label': 'About 8 km away',
          'skills': ['Exterior painting'],
          'matched_skills': [],
          'required_count': 2,
          'matched_count': 0,
          'match_tier': 1,
          'same_trade': true,
          'verification_state': 'pending',
          'is_new': true,
          'criteria': [
            {'key': 'rate', 'met': null, 'text': 'Rate to be discussed'},
          ],
        },
      ], jobId: 1);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkerBrowseProvider>.value(value: browse),
        ChangeNotifierProvider<InvitationProvider>.value(value: InvitationProvider()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMatchedWorkersSheet(context,
                    jobId: 1, jobTitle: 'Repainting of a three bedroom bungalow'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('Matched workers'), findsOneWidget);
    expect(find.text('2 workers fit, best first'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/matched_sheet.png'));
  });
}
