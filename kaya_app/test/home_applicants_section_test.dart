import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/jobs/widgets/applicants_section.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    The people who applied, on the employer's home screen.

    Ranking is free and presentation is premium: every applicant shows, in
    the server's best-match order, and a worker who topped up arrives with
    their resume open. A free one arrives as the card always looked.
*/
void main() {
  const jobId = 41;

  Map<String, dynamic> job() => {
        'id': jobId,
        'title': 'Rewire a sari-sari store in Barangay Nancayasan',
        'status': 'open',
        'is_live': true,
        'application_count': 3,
        'pending_application_count': 3,
      };

  Map<String, dynamic> applicant(
    int id,
    String name, {
    bool premium = false,
    String status = 'pending',
  }) =>
      {
        'application_id': id,
        'application_status': status,
        'worker_id': id + 100,
        'worker_name': name,
        'worker_rating': '4.80',
        'worker_rating_count': 12,
        'is_verified': true,
        'times_hired_before': 0,
        'skills': [
          'Electrical Installation and Maintenance',
          'Wiring',
          'Panel Board Assembly',
          'Lighting Fixture Installation',
          'Solar Panel Installation',
        ],
        'is_premium': premium,
        'experience_label': '6 years',
        'jobs_completed': 14,
        'licenses': ['TESDA NC II Electrical Installation and Maintenance'],
        'certifications': ['Occupational Safety and Health Training Certificate'],
      };

  Widget host({
    required List<Map<String, dynamic>> applicants,
    bool employerMode = true,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()
            ..reconcile(hasWorker: !employerMode, hasEmployer: employerMode),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(
          value: ApplicationProvider()
            ..seedHomeApplicants(applicants, jobId: jobId),
        ),
        ChangeNotifierProvider<JobProvider>.value(
          value: JobProvider()..seedMyJobs([job()]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: const ApplicantsSection()),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget widget,
      {double width = 412, double scale = 1.0}) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 5000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: widget,
    ));
    await tester.pump();
  }

  testWidgets('applicants show in the order they came, with Accept',
      (tester) async {
    await pump(
      tester,
      host(applicants: [
        applicant(1, 'Best Fit Dela Cruz'),
        applicant(2, 'Second Fit Santos'),
      ]),
    );

    expect(find.text('Applicants'), findsOneWidget);
    expect(find.text('Accept'), findsNWidgets(2));

    final first = tester.getTopLeft(find.text('Best Fit Dela Cruz')).dy;
    final second = tester.getTopLeft(find.text('Second Fit Santos')).dy;
    expect(first, lessThan(second), reason: 'the server order is the ranking');
  });

  testWidgets('a topped-up applicant arrives with the resume open',
      (tester) async {
    await pump(tester, host(applicants: [applicant(1, 'Paid', premium: true)]));

    expect(find.text('TESDA NC II Electrical Installation and Maintenance'),
        findsOneWidget);
    expect(find.text('6 years'), findsOneWidget);
    // Every skill, not the first three.
    expect(find.text('Solar Panel Installation'), findsOneWidget);
  });

  testWidgets('a free applicant arrives as the card always looked',
      (tester) async {
    await pump(tester, host(applicants: [applicant(1, 'Free')]));

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('TESDA NC II Electrical Installation and Maintenance'),
        findsNothing);
    expect(find.text('+2 more'), findsOneWidget);
  });

  testWidgets('someone already answered is not on home', (tester) async {
    await pump(
      tester,
      host(applicants: [applicant(1, 'Taken', status: 'accepted')]),
    );

    expect(find.text('Taken'), findsNothing);
    expect(find.text('Applicants'), findsNothing);
  });

  testWidgets('a worker never sees it', (tester) async {
    await pump(
      tester,
      host(applicants: [applicant(1, 'Hidden')], employerMode: false),
    );

    expect(find.text('Applicants'), findsNothing);
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('the open resume fits ${width.toInt()}px at scale $scale',
          (tester) async {
        final complaints = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            complaints.add(d.exceptionAsString().split('\n').first);
            return;
          }
          previous?.call(d);
        };

        try {
          await RenderHarness.loadFonts(tester);
          await pump(
            tester,
            host(applicants: [
              applicant(1, 'Ricardo Bumanglag Dela Cruz Jr.', premium: true),
            ]),
            width: width,
            scale: scale,
          );

          // On screen first, or this passes over a blank area.
          expect(find.text('Ricardo Bumanglag Dela Cruz Jr.'), findsOneWidget);
        } finally {
          FlutterError.onError = previous;
        }

        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
