import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/search_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Search results with jobs in them.

    The job card is shared with the home carousels, where the parent fixes
    its height. Here it sits in a vertical list and has to size itself, with
    the bookmark on and every optional line present: the pay, a
    barangay-city-province address with a distance beside it, a schedule,
    the applicant count and the posted-ago under it.
*/
void main() {
  Job job(String title, {bool urgent = false, int? match}) => Job(
        id: title.hashCode,
        title: title,
        company: 'Santiago Construction and General Services Incorporated',
        location: 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        salaryMin: 800,
        salaryMax: 1200,
        salaryPeriod: 'day',
        distance: 3.4,
        category: 'Construction',
        requiredSkills: const ['Masonry', 'Tile setting'],
        isUrgent: urgent,
        requiresVerification: true,
        matchScore: match,
        applicantCount: 12,
        postedAt: DateTime.now().subtract(const Duration(hours: 5)),
        startDate: DateTime.now().add(const Duration(days: 6)),
        endDate: DateTime.now().add(const Duration(days: 17)),
        startTime: '07:30',
        isSaved: urgent,
      );

  Widget searchWith(JobProvider jobs, double textScale, WidgetTester tester) {
    return MediaQuery(
      data: MediaQueryData.fromView(tester.view)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(
              create: (_) => WorkerProfileProvider(ApiClient())),
          ChangeNotifierProvider<JobProvider>.value(value: jobs),
          ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
          // A worker-only account, so the screen opens on jobs.
          ChangeNotifierProvider<AppModeProvider>.value(
            value: AppModeProvider()
              ..reconcile(hasWorker: true, hasEmployer: false),
          ),
          ChangeNotifierProvider(create: (_) => ApplicationProvider()),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
          ChangeNotifierProvider(create: (_) => MessagingProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
  }

  List<Job> results() => [
        job('Experienced mason needed for a two storey residential build',
            urgent: true, match: 88),
        job('Tile setter', match: 45),
        job('Concrete pouring crew needed this weekend in Sta. Barbara'),
      ];

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required double textScale,
    required double width,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        complaints.add(text.split('\n').first.trim());
        return;
      }
      previous?.call(details);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      tester.view.physicalSize = Size(width * 2, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // The screen's own fetch fails without a server and leaves what was
      // seeded in place, which is the behaviour the list has on bad signal.
      final jobs = JobProvider()..seedPublicJobs(results());

      await tester.pumpWidget(searchWith(jobs, textScale, tester));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Tile setter'),
        findsOneWidget,
        reason: 'The job list never rendered, so nothing was checked.',
      );
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNWidgets(2));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets(
        'populated search results fit ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(
            tester,
            textScale: scale,
            width: width,
          );

          expect(
            complaints,
            isEmpty,
            reason: 'Search results overflowed at ${width.toInt()}px, '
                'text scale $scale:\n  ${complaints.join('\n  ')}',
          );
        },
      );
    }
  }
}
