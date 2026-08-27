import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/category_model.dart';
import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/unified_home_screen.dart';
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
    The home screen with content on it.

    The busiest screen in the app, and the sweep next door renders it with
    empty providers - so no category tiles, no job cards, nothing that can
    overflow. Reported as "bottom overflow on the 4 job categories", which an
    empty home has none of.

    The category names here are the real ones from the seeder, including
    "Appliance Repair", which is the longest and the one that decides whether
    the tile fits.
*/
void main() {
  /// The real taxonomy, not three short words.
  List<CategoryModel> categories() => const [
        'Plumbing',
        'Electrical',
        'Carpentry',
        'Appliance Repair',
        'Pest Control',
        'Landscaping',
        'Cleaning',
        'Automotive',
      ]
          .asMap()
          .entries
          .map((e) => CategoryModel(id: e.key + 1, name: e.value))
          .toList();

  Job job(String title) => Job(
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
        isUrgent: true,
      );

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required double textScale,
    required double width,
    required bool workerMode,
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

      final worker = WorkerProfileProvider(ApiClient())
        ..seedCategories(categories());

      final jobs = JobProvider()
        ..seedPublicJobs([
          job('Experienced mason needed for a two storey residential build'),
          job('Tile setter'),
        ]);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider<WorkerProfileProvider>.value(value: worker),
              ChangeNotifierProvider<JobProvider>.value(value: jobs),
              ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
              ChangeNotifierProvider(create: (_) => VerificationProvider()),
              ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
              ChangeNotifierProvider(create: (_) => LocationProvider()),
              ChangeNotifierProvider(create: (_) => CreditsProvider()),
              /*
                  The mode decides which category row is drawn, and the two
                  are not variations on a theme - worker view renders four
                  hardcoded tiles in a Row of Expandeds, everything else
                  renders the server's categories in a scrolling list. Only
                  one of them was ever reached by a test, and the overflow was
                  in the other.
              */
              ChangeNotifierProvider<AppModeProvider>.value(
                value: AppModeProvider()
                  ..reconcile(hasWorker: true, hasEmployer: !workerMode),
              ),
              ChangeNotifierProvider(create: (_) => ApplicationProvider()),
              ChangeNotifierProvider(create: (_) => InvitationProvider()),
              ChangeNotifierProvider(create: (_) => MessagingProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
            ],
            child: const MaterialApp(home: UnifiedHomeScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      /*
          Proof the screen actually drew the thing under test.

          Without this the test passes whenever the categories fail to render
          at all - which is the same false pass that hid the profile header
          bug for days. A test that reports success over an empty screen is
          worse than no test, because it is believed.
      */
      // In worker view the tiles are the four fixed ones; otherwise they are
      // the seeded categories. Either way something has to be on screen, or
      // the test is reporting success over a blank page.
      expect(
        find.text(workerMode ? 'Top Rated' : 'Appliance Repair'),
        findsWidgets,
        reason: 'The category tiles never rendered, so nothing was checked.',
      );

      // Scrolled, because a sliver list only lays out what is on screen and
      // the sections further down would never be built otherwise.
      for (var i = 0; i < 5; i++) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -350),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final workerMode in <bool>[true, false]) {
    final view = workerMode ? 'worker view' : 'hybrid view';

    for (final width in <double>[412, 390, 360, 320]) {
      for (final scale in <double>[1.0, 1.15, 1.3]) {
        testWidgets(
          'a populated home in $view fits ${width.toInt()}px at text scale $scale',
          (tester) async {
            final complaints = await overflowsIn(
              tester,
              textScale: scale,
              width: width,
              workerMode: workerMode,
            );

            expect(
              complaints,
              isEmpty,
              reason: 'The home screen in $view overflowed at '
                  '${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}',
            );
          },
        );
      }
    }
  }
}
