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
import 'package:kaya_app/data/models/worker_profile_model.dart';
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

  /*
      A worker for the "Most hired" row, with the long name and the
      barangay-city-province address that make a card overflow.
  */
  WorkerProfile hiredWorker(String name) => WorkerProfile(
        id: name.hashCode,
        userId: name.hashCode,
        name: name,
        primarySkill: 'Mason and tile setter',
        location: 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        rating: 4.8,
        reviewCount: 12,
        completedJobs: 34,
        isVerified: true,
        distance: 3.4,
      );
  Job job(String title, {bool boosted = false}) => Job(
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
        isBoosted: boosted,
      );

  /*
      A hire in progress, as myApplications returns one.

      Long on purpose: the longest real job title, a company name with a
      suffix, and a deadline already past so the card shows the Mark as
      complete button rather than the shorter waiting note. That button plus
      the half-state sentence is the tallest this card gets.
  */
  Map<String, dynamic> liveHire() => {
        'id': 9001,
        'status': 'accepted',
        'worker_completed_at': null,
        'employer_completed_at': null,
        'conversation_id': 55,
        'job': {
          'id': 4001,
          'title': 'Experienced mason needed for a two storey residential build',
          'company': 'Villanueva-Santos Construction Supply and Hardware',
          'location': 'Brgy. Nancayasan, Urdaneta City, Pangasinan',
          'start_date': '2026-09-01',
          'end_date': '2026-09-03',
          'status': 'in_progress',
        },
      };

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
          // Promoted, so the "Promoted jobs" row has a card in it. Without
          // one the row renders nothing and the sweep measures a blank strip.
          job('Urgent: concrete pouring crew needed this weekend', boosted: true),
        ]);

      final directory = WorkerBrowseProvider()
        ..seedWorkers(
          directory: [hiredWorker('Ricardo Bumanglag Dela Cruz Jr.')],
          hired: [
            hiredWorker('Ricardo Bumanglag Dela Cruz Jr.'),
            hiredWorker('Maria Cristina Villanueva-Santos'),
          ],
        );

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
              // Seeded, so ActiveSection actually renders. Created
              // empty it drew nothing and the sweep measured a blank box.
              ChangeNotifierProvider<ApplicationProvider>.value(
                value: ApplicationProvider()..seedApplications([liveHire()]),
              ),
              ChangeNotifierProvider(create: (_) => InvitationProvider()),
              ChangeNotifierProvider(create: (_) => MessagingProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider<WorkerBrowseProvider>.value(
                  value: directory),
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
      // The same seeded categories in both views now. Worker view used to
      // show four fixed tiles - Skilled, Verified, Top Rated, Available -
      // which are things a worker is rather than work anyone is looking for,
      // and each one ran a text search for its own label.
      /*
          Seen at some point in the scroll below, not necessarily at rest.

          The Active section above them is the full My Activity card now,
          tall enough to push the tiles under the fold at 320px - so the
          tiles are looked for on every step of the scroll, the same way
          the recommendation row is.
      */
      final categoryTile = find.text('Appliance Repair');
      var sawCategories = categoryTile.evaluate().isNotEmpty;

      /*
          And the work-in-progress card, for the same reason.

          ActiveSection renders nothing when there is no live
          hire, so a sweep with an unseeded ApplicationProvider measured a
          zero-height box and called it a pass. The seeded hire above is
          what makes the Mark as complete button and the long job title
          part of what is being measured.
      */
      final activeHeading = find.text('Active');
      var sawActive = activeHeading.evaluate().isNotEmpty;

      /*
          Categories first, then the work in progress.

          Active sat above the categories and pushed them off the first
          screen for anyone with a hire. Each one's place in the scroll is
          recorded as it passes - position on screen plus how far the list
          has scrolled - so the two need not be on screen at the same time:
          the banner carousel above them can hold them a screen apart.
      */
      var orderChecked = false;
      double? categoryAt, activeAt;
      double scrolled() => tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      void checkOrder() {
        if (categoryTile.evaluate().isNotEmpty) {
          categoryAt ??= scrolled() + tester.getTopLeft(categoryTile.first).dy;
        }
        if (activeHeading.evaluate().isNotEmpty) {
          activeAt ??= scrolled() + tester.getTopLeft(activeHeading).dy;
        }
        if (categoryAt == null || activeAt == null || orderChecked) return;
        expect(categoryAt, lessThan(activeAt!), reason: 'Active is above the categories again.');
        orderChecked = true;
      }
      checkOrder();

      /*
          The recommendation row for this side has to appear at some point.

          It draws nothing when its list is empty, so without this the sweep
          measures a blank strip and reports that it fits - the same false
          pass the seeded providers above exist to prevent. Watched during the
          scroll rather than after it: a sliver that has gone off the top is
          disposed, so looking once at the end finds nothing whether it
          rendered or not.
      */
      final rowHeading = find.text(workerMode ? 'Promoted jobs' : 'Most hired');
      var sawRow = rowHeading.evaluate().isNotEmpty;

      // Scrolled, because a sliver list only lays out what is on screen and
      // the sections further down would never be built otherwise.
      // Six, since the home carousel sits above these rows.
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -350),
        );
        await tester.pump(const Duration(milliseconds: 120));

        sawRow = sawRow || rowHeading.evaluate().isNotEmpty;
        sawCategories = sawCategories || categoryTile.evaluate().isNotEmpty;
        sawActive = sawActive || activeHeading.evaluate().isNotEmpty;
        checkOrder();
      }

      expect(
        sawActive,
        isTrue,
        reason: 'The work in progress section never rendered, so the '
            'completion card was not measured.',
      );
      expect(orderChecked, isTrue,
          reason: 'Categories or Active never rendered, so their order was not checked.');

      expect(
        sawCategories,
        isTrue,
        reason: 'The category tiles never rendered, so nothing was checked.',
      );

      expect(
        sawRow,
        isTrue,
        reason: 'The recommendation row never rendered, so nothing was checked.',
      );
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
