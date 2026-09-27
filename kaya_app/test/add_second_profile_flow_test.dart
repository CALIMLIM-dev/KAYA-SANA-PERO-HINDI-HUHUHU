import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/skill_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/screens/add_second_profile_flow.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Adding a worker profile to an account that already has an employer one.

    The seven-page setup flow onboards somebody the app knows nothing about.
    An account with a profile already has the name, the photo, the verified ID
    and the town, so it is asked for its trade and nothing else.

    What these assert is mostly what must not happen: no request that could
    leave a half-made profile, no placeholder ids sent to a server that will
    reject them, and no profile created by backing out of a dialog.
*/
void main() {
  late _RecordingAdapter adapter;

  setUp(() {
    adapter = _RecordingAdapter();
    ApiClient.testAdapter = adapter;
  });

  tearDown(() {
    ApiClient.testAdapter = null;
  });

  /// An individual employer with no worker profile — the account this is for.
  Map<String, dynamic> individualEmployer() => {
        'id': 7,
        'name': 'Ben Santos',
        'employer_type': 'individual',
        'worker_profile_exists': false,
        'worker_setup_completed': false,
        'employer_profile_exists': true,
        'employer_setup_completed': true,
      };

  /*
      Runs one create against the recording adapter and hands back its body.

      testWidgets runs in a fake-async zone where a real HTTP future never
      completes, because nothing fires the timer that would resolve it.
      runAsync steps outside that zone for the duration of the call.

      The channel stub is needed either way: ApiClient reads the saved token
      from secure storage on every request.
  */
  Future<Map<String, dynamic>?> create(
    WidgetTester tester, {
    required int categoryId,
    required List<SkillModel> skills,
  }) async {
    RenderHarness.stubPlatformChannels(tester);

    await tester.runAsync(() async {
      await WorkerProfileProvider(ApiClient()).createFromAccount(
        categoryId: categoryId,
        skills: skills,
      );
    });

    return adapter.bodyFor('/worker/profile/from-account');
  }

  group('who is offered it', () {
    test('an individual employer with no worker profile is', () {
      final auth = AuthProvider()..seedUser(individualEmployer());

      expect(auth.canAddWorkerProfileFromAccount, isTrue);
    });

    test('a company employer is not', () {
      /*
          The one exception to an account holding both profiles. A registered
          business hiring through KAYA is not also a tradesperson looking for
          work, and a verified-business badge on an account that is sometimes a
          company and sometimes a person vouches for nothing.
      */
      final auth = AuthProvider()
        ..seedUser({...individualEmployer(), 'employer_type': 'company'});

      expect(auth.canAddWorkerProfileFromAccount, isFalse);
    });

    test('an account with no profile at all is not', () {
      // There is nothing to inherit: no town, no confirmed name, no
      // verification. That account belongs in the full setup flow.
      final auth = AuthProvider()
        ..seedUser({
          'id': 8,
          'name': 'Nobody Yet',
          'worker_profile_exists': false,
          'employer_profile_exists': false,
        });

      expect(auth.canAddWorkerProfileFromAccount, isFalse);
    });

    test('an account that already has both is not offered it again', () {
      final auth = AuthProvider()
        ..seedUser({...individualEmployer(), 'worker_profile_exists': true});

      expect(auth.canAddWorkerProfileFromAccount, isFalse);
    });

    /*
        And the same the other way round.

        A worker adding the employer side used to walk three more pages -
        personal details, a photo and an ID - and the account already held every
        answer. The two directions are offered on the same terms so neither
        becomes the one that still asks.
    */
    test('a worker with no employer profile is offered the employer side', () {
      final auth = AuthProvider()
        ..seedUser({
          'id': 9,
          'name': 'Ben Santos',
          'worker_profile_exists': true,
          'employer_profile_exists': false,
        });

      expect(auth.canAddEmployerProfileFromAccount, isTrue);
      expect(auth.canAddWorkerProfileFromAccount, isFalse);
    });

    test('an account with no profile is not offered the employer side', () {
      final auth = AuthProvider()
        ..seedUser({
          'id': 10,
          'name': 'Nobody Yet',
          'worker_profile_exists': false,
          'employer_profile_exists': false,
        });

      expect(auth.canAddEmployerProfileFromAccount, isFalse);
    });
  });

  group('the trade the profile is filed under', () {
    SkillModel skill(String name, int categoryId) =>
        SkillModel(id: 1, name: name, categoryId: categoryId);

    test('is the one most of the chosen skills belong to', () {
      // A worker who picked four carpentry skills and one plumbing one is a
      // carpenter. browse() filters on this, so guessing it wrong hides them
      // from the employers looking for them.
      final category = SecondProfileFlow.dominantCategory([
        skill('Framing', 3),
        skill('Cabinet making', 3),
        skill('Pipe fitting', 9),
      ]);

      expect(category, 3);
    });

    test('is nothing when every skill is one the catalogue has never seen', () {
      // AddSkillsScreen represents those as category 0 — a placeholder, not a
      // row. Sending it would fail the server's exists: rule, so the flow asks
      // rather than guesses.
      final category = SecondProfileFlow.dominantCategory([
        SkillModel(id: -1, name: 'Bamboo scaffolding', categoryId: 0),
      ]);

      expect(category, isNull);
    });
  });

  group('the request that creates it', () {
    testWidgets('is one request, so a failure cannot half-make a profile',
        (tester) async {
      /*
          The setup flow does this as a PUT for the location and then one POST
          per skill. Any of those failing leaves a real profile behind with no
          category and no skills - which reads as finished to the router and as
          empty to every employer looking at it.
      */
      await create(
        tester,
        categoryId: 3,
        skills: [SkillModel(id: 11, name: 'Framing', categoryId: 3)],
      );

      final writes = adapter.requests
          .where((r) => r.method != 'GET')
          .map((r) => r.path)
          .toList();

      expect(writes, ['/worker/profile/from-account']);
    });

    testWidgets('does not send the placeholder ids of a custom skill',
        (tester) async {
      /*
          A skill the catalogue has never seen comes back from the picker as id
          -1 in category 0. Sent as-is they fail the server's exists: rules and
          take the whole profile down with them, so they go as null and the
          skill is stored by name under the profile's own trade.
      */
      final body = (await create(
        tester,
        categoryId: 3,
        skills: [
          SkillModel(id: 11, name: 'Framing', categoryId: 3),
          SkillModel(id: -1, name: 'Bamboo scaffolding', categoryId: 0),
        ],
      ))!;

      final skills = (body['skills'] as List).cast<Map>();

      expect(body['category_id'], 3);

      expect(skills.first['skill_id'], 11);
      expect(skills.first['category_id'], 3);

      expect(
        skills.last.containsKey('skill_id'),
        isFalse,
        reason: 'A placeholder id was sent to a column with a foreign key.',
      );
      expect(skills.last.containsKey('category_id'), isFalse);
      expect(skills.last['skill_name'], 'Bamboo scaffolding');
    });

    testWidgets('does not send a location, because it is inherited',
        (tester) async {
      // One person lives in one place. The server copies it from the profile
      // the account already has, so there is one answer rather than two that
      // can disagree.
      final body = (await create(
        tester,
        categoryId: 3,
        skills: [SkillModel(id: 11, name: 'Framing', categoryId: 3)],
      ))!;

      expect(body.containsKey('location'), isFalse);
      expect(body.containsKey('location_id'), isFalse);
    });
  });

  group('the dialog', () {
    Future<void> pumpEntry(WidgetTester tester, AuthProvider auth) async {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(
                create: (_) => WorkerProfileProvider(ApiClient())),
            ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => SecondProfileFlow.addWorker(context),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('says what it does and what carries over', (tester) async {
      final auth = AuthProvider()..seedUser(individualEmployer());

      await pumpEntry(tester, auth);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add a Worker Profile'), findsOneWidget);

      // The reason this is one tap rather than seven pages. Without it the
      // flow reads as though it skipped something it should have asked.
      expect(
        find.textContaining('carry over'),
        findsOneWidget,
        reason: 'The dialog did not say that the account details are reused.',
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('writes nothing when it is cancelled', (tester) async {
      final auth = AuthProvider()..seedUser(individualEmployer());

      await pumpEntry(tester, auth);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        adapter.requests.where((r) => r.method != 'GET'),
        isEmpty,
        reason: 'Backing out of the dialog still changed the account.',
      );
    });
  });

  group('the screen held while it is made', () {
    /*
        Held for a reason beyond looking busy: the moment /me reports the new
        profile, AppModeProvider re-derives the account as hybrid and the home
        screen changes shape underneath. Without something covering that, the
        employer home visibly becomes the unified home mid-request.
    */
    testWidgets('fits the narrowest phone at the largest text scale',
        (tester) async {
      await RenderHarness.loadFonts(tester);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const MaterialApp(
            home: SecondProfilePreparingScreen(
              message: 'Setting up your worker profile',
            ),
          ),
        ),
      );
      await tester.pump();

      // Asserted on screen before asserted to fit: a test that passes over a
      // blank area is worse than no test, because it gets believed.
      expect(find.text('Setting up your worker profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/*
    Records what was sent, and answers everything successfully.

    These tests are about the shape of the request, so the response only has to
    be well formed enough that the provider reaches the end of its happy path.
*/
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  Map<String, dynamic>? bodyFor(String path) {
    for (final request in requests) {
      if (request.path == path && request.data is Map) {
        return (request.data as Map).cast<String, dynamic>();
      }
    }

    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'ok',
        'data': {'location': 'Urdaneta City', 'category_id': 3},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
