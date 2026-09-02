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
    My Activity, rendered so it can actually be looked at.

    The overflow tests next door prove the strip fits and carries the right
    numbers; neither of those says whether it looks like anything. These write
    PNGs of the three accounts that draw genuinely different layouts — one
    tile, two tiles, three — with realistic Philippine content, so a design
    change is reviewed by looking at it rather than by reading the widget tree
    and hoping.
*/
void main() {
  Map<String, dynamic> application(String status, String title) => {
        'id': '$status$title'.hashCode,
        'status': status,
        // A thread exists from the hire onward, and keeps existing after the
        // job finishes — the server returns it for both now that the lookup is
        // keyed by employer rather than job. Pending and rejected have none,
        // because messaging genuinely unlocks on hire.
        'conversation_id':
            status == 'accepted' || status == 'completed' ? 12 : null,
        'job': {
          'id': title.hashCode,
          'title': title,
          'status': status == 'accepted' ? 'in_progress' : 'open',
          'employer': {
            'id': 9,
            'name': 'Santiago Construction and General Services',
            'is_verified': true,
          },
        },
      };

  Map<String, dynamic> invitation(String status) => {
        'id': status.hashCode,
        'status': status,
        'job': {'id': 1, 'title': 'Tile setter, Urdaneta City'},
        'employer': {'id': 9, 'name': 'Santiago Construction', 'is_verified': true},
      };

  Map<String, dynamic> job(String title, String status,
          {int pending = 0, int total = 0}) =>
      {
        'id': title.hashCode,
        'status': status,
        'title': title,
        'location': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'application_count': total,
        'pending_application_count': pending,
      };

  Widget screen({required bool worker, required bool employer}) {
    final applications = ApplicationProvider()
      ..seedApplications([
        application('pending', 'Experienced mason for a two storey residential build'),
        application('pending', 'Aircon cleaning and general maintenance'),
        application('accepted', 'Carpenter for built in cabinet installation'),
        application('completed', 'Repainting of a three bedroom bungalow'),
        application('rejected', 'Electrical rewiring, Barangay Bayaoas'),
      ]);

    final invitations = InvitationProvider()
      ..seedInvitations([invitation('pending'), invitation('pending')]);

    final jobs = JobProvider()
      ..seedMyJobs([
        job('Househelp needed, live out, Urdaneta City', 'open', pending: 4, total: 9),
        job('Delivery rider with own motorcycle', 'in_progress', pending: 1, total: 6),
        job('Landscaping for a residential lot', 'completed', total: 3),
      ]);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()
            ..reconcile(hasWorker: worker, hasEmployer: employer),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(value: applications),
        ChangeNotifierProvider<InvitationProvider>.value(value: invitations),
        ChangeNotifierProvider<JobProvider>.value(value: jobs),
      ],
      child: const MaterialApp(home: ApplicationsScreen()),
    );
  }

  testWidgets('my activity, hybrid account', (tester) async {
    await RenderHarness.capture(
      tester,
      screen(worker: true, employer: true),
      name: 'activity_hybrid',
      size: const Size(1080, 1800),
    );
  });

  testWidgets('my activity, worker only', (tester) async {
    await RenderHarness.capture(
      tester,
      screen(worker: true, employer: false),
      name: 'activity_worker',
      size: const Size(1080, 1800),
    );
  });

  testWidgets('my activity, employer only', (tester) async {
    await RenderHarness.capture(
      tester,
      screen(worker: false, employer: true),
      name: 'activity_employer',
      size: const Size(1080, 1800),
    );
  });

  /// The tight case: a small phone with the system font turned up, which is
  /// where alignment goes wrong first.
  testWidgets('my activity, hybrid, 360px at text scale 1.3', (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    tester.view.physicalSize = const Size(720, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: screen(worker: true, employer: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/activity_hybrid_tight.png'),
    );
  });

  /*
      The History tab, which the captures above never reached.

      They all render the first tab, so every screenshot so far has been of
      Active — and History is where the rows differ most: a completed job
      carries a review button and a Message button, a rejected one carries
      neither, and they sit in the same list. Whether that list looks
      consistent is exactly the thing a screenshot of Active cannot answer.
  */
  testWidgets('my activity, worker history', (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(screen(worker: true, employer: false));
    await tester.pump(const Duration(milliseconds: 300));

    // The tab, not the label inside it: tapping the Text hits a child that
    // does not carry the gesture, and the view stays on Active while the test
    // happily screenshots the wrong tab.
    await tester.tap(find.byType(Tab).last);
    // TabBarView animates, and one pump lands mid-transition. Several fixed
    // pumps rather than pumpAndSettle, which hangs on the loading spinner.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/activity_worker_history.png'),
    );
  });
}
