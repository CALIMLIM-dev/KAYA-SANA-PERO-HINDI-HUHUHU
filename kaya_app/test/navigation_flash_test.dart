import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/employer/screens/setup_employer_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/employer_profile_router.dart';
import 'package:kaya_app/features/profile/screens/my_employer_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/my_worker_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/worker_profile_router.dart';
import 'package:kaya_app/features/worker/screens/worker_setup_flow_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    The wrong screen, shown briefly.

    Every profile flag on AuthProvider reads `_user?['...'] ?? false`, so
    before /me answers they all say "no profile" — which is the exact same
    answer as an account that genuinely has none. Anything that branches on
    those flags without first asking whether the server has replied will show
    the setup flow to someone who finished setting up months ago.

    That window is short on a good connection, which is why it reads as a
    flash rather than a bug, and why it survives manual testing on wifi. It is
    not short on Philippine mobile data.

    These tests hold the app in that window on purpose and assert what is on
    screen while it is open. They are about the frame *before* the data
    arrives — the state every other test in this folder skips past.
*/
void main() {
  /*
      Answer every request instantly, so no timeout timer is ever armed.

      These screens fetch on mount. Left to reach a real socket they arm two
      30-second timers apiece and the binding blames a later, unrelated test
      for them. 404 is deliberate: it exercises the same path a signed-out or
      empty account takes, and every provider here already handles it.
  */
  setUpAll(() {
    ApiClient.testAdapter = _ImmediateAdapter();
  });

  tearDownAll(() {
    ApiClient.testAdapter = null;
  });

  /// A /me payload for an account that finished setting up as a worker.
  Map<String, dynamic> establishedWorker() => {
        'id': 1,
        'name': 'Ricardo Bumanglag Dela Cruz Jr.',
        'email': 'ricardo@example.com',
        'worker_profile_exists': true,
        'worker_setup_completed': true,
        'employer_profile_exists': false,
        'employer_setup_completed': false,
      };

  /// The same, for the employer side.
  Map<String, dynamic> establishedEmployer() => {
        'id': 2,
        'name': 'Santiago Construction',
        'email': 'santiago@example.com',
        'worker_profile_exists': false,
        'worker_setup_completed': false,
        'employer_profile_exists': true,
        'employer_setup_completed': true,
      };

  Future<void> pumpRouter(
    WidgetTester tester,
    Widget router, {
    required AuthProvider auth,
  }) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
          ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
          ChangeNotifierProvider(create: (_) => JobProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
        ],
        child: MaterialApp(home: router),
      ),
    );
    /*
        Pump until the on-mount fetches have come and gone.

        The first pump runs the post-frame callbacks that start them; the
        adapter answers immediately, but Dio only cancels its timeout timer
        once that response has been delivered, which takes another turn of the
        loop.

        This has to happen here, in the test body. The binding checks for
        pending timers when the body ends and before any addTearDown runs, so
        cleanup registered there is always too late to be believed.
    */
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('the frame before /me answers', () {
    /*
        The reported flash, reduced to its smallest form.

        An established worker opens their profile while /me is still in
        flight. Nothing is known yet, so nothing about their account may be
        asserted — least of all that they have no profile.
    */
    testWidgets(
      'an established worker is never shown the setup flow while /me is in flight',
      (tester) async {
        final auth = AuthProvider()..seedUser(null, fetched: false);

        await pumpRouter(tester, const WorkerProfileRouter(), auth: auth);

        expect(
          find.byType(WorkerSetupFlowScreen),
          findsNothing,
          reason: 'The setup flow was shown to a worker whose profile had not '
              'been loaded yet. Their flags default to false before /me '
              'answers, which is indistinguishable from having no profile.',
        );
      },
    );

    testWidgets(
      'an established employer is never shown the setup flow while /me is in flight',
      (tester) async {
        final auth = AuthProvider()..seedUser(null, fetched: false);

        await pumpRouter(tester, const EmployerProfileRouter(), auth: auth);

        expect(
          find.byType(SetupEmployerProfileScreen),
          findsNothing,
          reason: 'The employer setup flow was shown before /me answered.',
        );
      },
    );

    /*
        And the resolution: once the answer arrives, the right screen appears
        without the user doing anything.

        A guard that shows a spinner forever is not a fix, so the spinner has
        to be proven temporary as well as proven present.
    */
    testWidgets('the worker profile appears once /me lands', (tester) async {
      final auth = AuthProvider()..seedUser(null, fetched: false);

      await pumpRouter(tester, const WorkerProfileRouter(), auth: auth);
      expect(find.byType(MyWorkerProfileScreen), findsNothing);

      auth.seedUser(establishedWorker());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(MyWorkerProfileScreen),
        findsOneWidget,
        reason: 'The router stayed on the loading state after /me answered.',
      );
    });

    testWidgets('the employer profile appears once /me lands', (tester) async {
      final auth = AuthProvider()..seedUser(null, fetched: false);

      await pumpRouter(tester, const EmployerProfileRouter(), auth: auth);

      auth.seedUser(establishedEmployer());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MyEmployerProfileScreen), findsOneWidget);
    });
  });

  group('a genuinely new account still reaches setup', () {
    /*
        The guard must not swallow the real case.

        A new account has answered /me and the honest answer is "no profile".
        If the loading guard is written as "no flags means wait", these two
        spin forever and nobody can ever sign up.
    */
    testWidgets('no worker profile, /me answered, goes to setup',
        (tester) async {
      final auth = AuthProvider()
        ..seedUser({
          'id': 3,
          'name': 'New Account',
          'worker_profile_exists': false,
          'worker_setup_completed': false,
          'employer_profile_exists': false,
          'employer_setup_completed': false,
        });

      await pumpRouter(tester, const WorkerProfileRouter(), auth: auth);

      expect(
        find.byType(WorkerSetupFlowScreen),
        findsOneWidget,
        reason: 'A new account could not reach worker setup. The loading '
            'guard is treating "answered, and the answer is no" as "have not '
            'asked yet".',
      );
    });

    testWidgets('no employer profile, /me answered, goes to setup',
        (tester) async {
      final auth = AuthProvider()
        ..seedUser({
          'id': 4,
          'name': 'New Account',
          'worker_profile_exists': false,
          'worker_setup_completed': false,
          'employer_profile_exists': false,
          'employer_setup_completed': false,
        });

      await pumpRouter(tester, const EmployerProfileRouter(), auth: auth);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SetupEmployerProfileScreen), findsOneWidget);
    });
  });

  group('signing out does not leak the previous account', () {
    /*
        The flags are a plain map that logout replaces with null. What must
        not survive is the *authority* to answer questions about it — if
        `hasFetchedMe` stays true through a sign-out, the first frame of the
        next account answers "no profile" with confidence and sends an
        established worker into setup.
    */
    test('logout clears the answered flag, not just the payload', () async {
      final auth = AuthProvider()..seedUser(establishedWorker());
      expect(auth.hasFetchedMe, isTrue);
      expect(auth.workerProfileExists, isTrue);

      await auth.logout();

      expect(auth.user, isNull);
      expect(
        auth.hasFetchedMe,
        isFalse,
        reason: 'After logout the provider still believed it had heard from '
            'the server, so the next account would be judged on the previous '
            "account's absence of data.",
      );
    });

    testWidgets('the signed-out state shows no setup flow', (tester) async {
      final auth = AuthProvider()..seedUser(establishedWorker());

      await pumpRouter(tester, const WorkerProfileRouter(), auth: auth);
      expect(find.byType(MyWorkerProfileScreen), findsOneWidget);

      await auth.logout();
      await tester.pump();

      expect(
        find.byType(WorkerSetupFlowScreen),
        findsNothing,
        reason: 'Signing out flashed the setup flow on the way to the login '
            'screen.',
      );
    });
  });

  group('a half-finished profile resumes instead of displaying', () {
    /*
        A row is not a profile. One gets created the moment somebody starts
        setting one up, so "exists" and "finished" are different questions and
        the display screen is only correct for the second.

        The employer router carries this rule in a comment because it was
        reported: an abandoned attempt opened a profile screen with no name,
        no location, and no way to fill them in.
    */
    testWidgets('worker: exists but unfinished goes back to the flow',
        (tester) async {
      final auth = AuthProvider()
        ..seedUser({
          'id': 5,
          'name': 'Half Done',
          'worker_profile_exists': true,
          'worker_setup_completed': false,
          'employer_profile_exists': false,
          'employer_setup_completed': false,
        });

      await pumpRouter(tester, const WorkerProfileRouter(), auth: auth);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MyWorkerProfileScreen), findsNothing,
          reason: 'An unfinished worker profile opened the display screen.');
    });

    testWidgets('employer: exists but unfinished goes back to the flow',
        (tester) async {
      final auth = AuthProvider()
        ..seedUser({
          'id': 6,
          'name': 'Half Done',
          'worker_profile_exists': false,
          'worker_setup_completed': false,
          'employer_profile_exists': true,
          'employer_setup_completed': false,
        });

      await pumpRouter(tester, const EmployerProfileRouter(), auth: auth);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MyEmployerProfileScreen), findsNothing,
          reason: 'An unfinished employer profile opened the display screen.');
    });
  });

  group('the two sides behave identically', () {
    /*
        The employer router's own docblock says it: "the moment one grows a
        rule the other lacks is the moment a user finds a dead end on one side
        only". A hybrid account holds both of these, and a user who hits a
        flash on one side and not the other has no way to describe what they
        saw.

        This is the test that fails when the next rule is added to one router
        and not its twin.
    */
    testWidgets('neither router commits to a screen before /me answers',
        (tester) async {
      for (final entry in <String, Widget>{
        'worker': const WorkerProfileRouter(),
        'employer': const EmployerProfileRouter(),
      }.entries) {
        final auth = AuthProvider()..seedUser(null, fetched: false);
        await pumpRouter(tester, entry.value, auth: auth);

        expect(
          find.byType(CircularProgressIndicator),
          findsWidgets,
          reason: 'The ${entry.key} router decided what to show before it had '
              'anything to decide with. Its twin waits.',
        );
      }
    });
  });
}

/// A Dio adapter that answers straight away instead of opening a socket.
///
/// Nothing here reaches the network, so Dio never arms a connect or receive
/// timeout and no timer survives the test that created it.
class _ImmediateAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'success': false, 'message': 'not found in test'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
