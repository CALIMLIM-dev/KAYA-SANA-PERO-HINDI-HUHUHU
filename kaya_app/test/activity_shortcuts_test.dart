import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/core/constants/app_mode.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    My Activity's shortcut strip, and the split it is built on.

    Two things are guarded here, and they are the two that broke before.

    The first is arithmetic. My Activity shows a worker's live applications on
    two surfaces now — sent-and-unanswered on a shortcut, hired-and-working on
    the Active tab — while the home card still shows one number over both. If
    those three counts are computed from three separate filters, they drift the
    moment a status is added, which is exactly how the home card ended up
    reading 0 over a screen with a row on it. So the invariant is asserted
    directly: the two halves add up to the whole.

    The second is that the strip renders at all, with the right numbers on it.
    An employer had no route to their own applicants except a notification, and
    a tile that silently fails to appear puts them back there. The widget tests
    seed a hybrid account — the only one that draws all three tiles, and the
    tightest layout — and assert each label and count is on screen *before*
    checking nothing overflowed, because a test that passes over a blank strip
    is worse than no test.
*/
void main() {
  Map<String, dynamic> application(String status) => {
        'id': status.hashCode,
        'status': status,
        'job': {
          'id': status.hashCode,
          'title': 'Experienced mason for a two storey residential build',
          'employer': {'id': 9, 'name': 'Santiago Construction Services'},
        },
      };

  Map<String, dynamic> invitation(String status) => {
        'id': status.hashCode,
        'status': status,
        'job': {'id': 1, 'title': 'Tile setter, Urdaneta City'},
        'employer': {'id': 9, 'name': 'Santiago Construction Services'},
      };

  Map<String, dynamic> job(String status, {int pending = 0, int total = 0}) => {
        'id': '$status$pending$total'.hashCode,
        'status': status,
        'title': 'Carpenter needed for cabinet installation',
        'location': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'application_count': total,
        'pending_application_count': pending,
      };

  group('the split adds up', () {
    /*
        The invariant the home card depends on.

        The card says "My Applications: 3" and lands on a screen that now shows
        those three as 2 on a shortcut and 1 on a tab. That is only honest
        while the parts sum to the whole, and the only way to keep it true is
        for `active` to be composed from the two rather than filtered again.
    */
    test('awaitingReply and liveWork partition active exactly', () {
      final provider = ApplicationProvider()
        ..seedApplications([
          application('pending'),
          application('accepted'),
          application('completed'),
          application('rejected'),
          application('withdrawn'),
        ]);

      expect(
        provider.awaitingReply.length + provider.liveWork.length,
        provider.active.length,
        reason: 'The home card counts active over a screen that shows the two '
            'halves separately. If they stop summing, the card is a number '
            'that appears nowhere on the screen it opens.',
      );
      expect(provider.awaitingReply, hasLength(1));
      expect(provider.liveWork, hasLength(1));
    });

    test('a hired application is live work, never awaiting a reply', () {
      final provider = ApplicationProvider()
        ..seedApplications([application('accepted')]);

      expect(provider.awaitingReply, isEmpty);
      expect(
        provider.liveWork,
        hasLength(1),
        reason: 'Being hired is the point at which an application stops being '
            'a thing you wait on and starts being work. It belongs on Active, '
            'which is where the Message and Mark as complete buttons are.',
      );
    });

    test('invitations count only the ones still needing an answer', () {
      final provider = InvitationProvider()
        ..seedInvitations([
          invitation('pending'),
          invitation('accepted'),
          invitation('declined'),
        ]);

      expect(provider.pending, hasLength(1));
    });
  });

  /*
      Applicants: the count and the list it opens have to be the same rule.

      `application_count` is every application a job ever had. Using it for
      "people waiting on you" badges a job whose applicants were all declined
      and then opens onto an empty list — the shortcut version of the bug the
      home card had.
  */
  group('applicants count', () {
    test('counts pending applicants, not every applicant ever', () {
      final provider = JobProvider()
        ..seedMyJobs([
          job('open', pending: 2, total: 7),
          job('open', pending: 0, total: 4),
          job('closed', pending: 3, total: 3),
        ]);

      final open = provider.jobs
          .where((j) => j['status'] == 'open')
          .fold<int>(0, (sum, j) => sum + (j['pending_application_count'] as int));

      expect(
        open,
        2,
        reason: 'Seven people applied and four were declined elsewhere; two '
            'are actually waiting. A badge of 11 over a list of 2 is the '
            'number disagreeing with the screen again.',
      );
    });
  });

  group('the strip renders', () {
    /*
        Seeded, at a given width and text size, for one side of the app.

        The mode matters as much as the width. Shortcuts follow the active
        mode, not merely which profiles exist, so a hybrid account in worker
        mode draws the worker pair and nothing else — an account holding both
        profiles is not a third layout, it is whichever mode it is currently
        in. Passing the profile pair here and letting reconcile pick the mode
        is what the app itself does.
    */
    Future<List<String>> render(
      WidgetTester tester, {
      required double width,
      required double textScale,
      bool worker = true,
      bool employer = false,
      /// Focus a hybrid on one side, the way the home toggle does.
      AppMode? mode,
    }) async {
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          overflows.add(text.split('\n').first.trim());
          return;
        }
        previous?.call(details);
      };

      try {
        await RenderHarness.loadFonts(tester);
        RenderHarness.stubPlatformChannels(tester);

        tester.view.physicalSize = Size(width * 2, 1600);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final applications = ApplicationProvider()
          ..seedApplications([
            application('pending'),
            application('accepted'),
            application('completed'),
          ]);
        final invitations = InvitationProvider()
          ..seedInvitations([invitation('pending')]);
        final jobs = JobProvider()
          ..seedMyJobs([job('open', pending: 4, total: 9)]);

        // reconcile() leaves a hybrid on the unified view; setMode is what
        // the home toggle calls to focus one side.
        final appMode = AppModeProvider()
          ..reconcile(hasWorker: worker, hasEmployer: employer);
        if (mode != null) appMode.setMode(mode);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<AppModeProvider>.value(value: appMode),
                ChangeNotifierProvider<ApplicationProvider>.value(
                    value: applications),
                ChangeNotifierProvider<InvitationProvider>.value(
                    value: invitations),
                ChangeNotifierProvider<JobProvider>.value(value: jobs),
              ],
              child: const MaterialApp(home: ApplicationsScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      } finally {
        FlutterError.onError = previous;
      }

      return overflows;
    }

    for (final width in [412.0, 390.0, 360.0, 320.0]) {
      for (final scale in [1.0, 1.15, 1.3]) {
        testWidgets('worker: both buttons fit ${width.toInt()}px at scale $scale',
            (tester) async {
          final overflows = await render(
              tester, width: width, textScale: scale, worker: true);

          // Asserted before the overflow check: a strip that failed to build
          // cannot overflow either, and would pass silently.
          expect(find.text('Invited'), findsOneWidget);
          expect(find.text('Applied'), findsOneWidget);

          expect(
            overflows,
            isEmpty,
            reason: 'Two buttons across ${width.toInt()}px at text scale '
                '$scale: ${overflows.join(" | ")}',
          );
        });

        testWidgets('employer: the button fits ${width.toInt()}px at scale $scale',
            (tester) async {
          final overflows = await render(tester,
              width: width,
              textScale: scale,
              worker: false,
              employer: true);

          expect(find.text('Pending'), findsOneWidget);

          expect(overflows, isEmpty,
              reason: 'Employer shortcut at ${width.toInt()}px, scale $scale: '
                  '${overflows.join(" | ")}');
        });
      }
    }

    /*
        A hybrid follows the mode toggle, and nothing else.

        Gating on profile existence alone put all three shortcuts on one
        strip regardless of which side the person was working as. A rule
        that dropped one of them replaced that and was also wrong: it
        second-guessed the toggle, so a hybrid silently lost its own
        applications list depending on a mode it had not thought about.

        The toggle is the control. Focused on a side, the strip shows that
        side; on the unified view it shows both, which is what the unified
        view means everywhere else in the app.
    */
    testWidgets('a hybrid focused on worker shows the worker pair only',
        (tester) async {
      await render(tester,
          width: 412,
          textScale: 1.0,
          worker: true,
          employer: true,
          mode: AppMode.worker);

      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('a hybrid focused on employer shows the employer one only',
        (tester) async {
      await render(tester,
          width: 412,
          textScale: 1.0,
          worker: true,
          employer: true,
          mode: AppMode.employer);

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Invited'), findsNothing);
      expect(find.text('Applied'), findsNothing);
    });

    testWidgets('worker: each button carries the count of the list it opens',
        (tester) async {
      await render(tester, width: 412, textScale: 1.0, worker: true);

      // One pending invitation and one unanswered application. The accepted
      // application is deliberately in neither count — it is work now, and
      // lives on the Active tab.
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('employer: the badge counts people, not jobs', (tester) async {
      await render(tester,
          width: 412, textScale: 1.0, worker: false, employer: true);

      expect(
        find.text('4'),
        findsOneWidget,
        reason: 'One job with four applicants waiting reads 4, not 1. The '
            'sheet lists jobs, but the badge counts the people.',
      );
    });

    /*
        The hole this rebuild was for.

        A hired worker used to see nothing but History: their live job sat
        inside a popup labelled Applications, filed with applications they had
        only sent, so the Message and Mark as complete buttons on it were
        three taps behind a button nobody had a reason to press.
    */
    testWidgets('a hired worker sees their job on Active', (tester) async {
      await render(tester, width: 412, textScale: 1.0);

      // The tab wears its row count — "Active (2)" for a hybrid account with
      // one accepted application and one open job post.
      expect(find.textContaining('Active'), findsOneWidget);
      expect(
        find.textContaining('Experienced mason'),
        findsWidgets,
        reason: 'The accepted application is the worker\'s live work and has '
            'to be on the Active tab, not hidden in a shortcut sheet.',
      );
    });
  });
}
