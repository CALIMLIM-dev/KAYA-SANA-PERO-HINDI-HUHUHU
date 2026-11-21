import 'dart:convert';
import 'package:kaya_app/core/widgets/consent_check.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/auth/screens/google_password_screen.dart';
import 'package:kaya_app/features/community/screens/compose_community_post_screen.dart';
import 'package:kaya_app/features/community/screens/my_community_posts_screen.dart';
import 'package:kaya_app/features/employer/screens/employer_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/onboarding_verification_screen.dart';
import 'package:kaya_app/features/worker_profile/screens/worker_profile_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/community_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    The last six screens the November audit found with no test: two public
    profiles (and their Report / Block menu), the community compose and
    my-posts screens, the Google sign-up password step, and the sign-up ID
    step. Driven the way a person uses them, at a 360-wide phone with real
    fonts, against a fake server.
*/
void main() {
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
  });
  tearDown(() => ApiClient.testAdapter = null);

  Map<String, dynamic> me({bool worker = true, bool employer = false}) => {
        'id': 1, 'name': 'Ana Reyes', 'is_verified': true,
        'worker_profile_exists': worker, 'employer_profile_exists': employer,
      };

  Future<void> open(WidgetTester tester, Widget screen,
      {Object? args, required List<ChangeNotifierProvider> providers}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: providers,
      child: MaterialApp(
        routes: {'/wallet': (_) => const Scaffold(body: Text('Wallet Page'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push(MaterialPageRoute(
                    settings: RouteSettings(arguments: args),
                    builder: (_) => screen,
                  ));
                  server.popped = result ?? 'closed';
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets toasts and pop-up animations finish before the test ends.
  Future<void> settle(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

  group('Worker Profile', () {
    List<ChangeNotifierProvider> providers({int myId = 1}) => [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()..seedUser({...me(), 'id': myId})),
          ChangeNotifierProvider<WorkerBrowseProvider>(create: (_) => WorkerBrowseProvider()),
        ];

    testWidgets('shows the worker and lets you block them', (tester) async {
      await open(tester, const WorkerProfileScreen(), args: {'workerId': 9}, providers: providers());

      expect(find.text('Ben Santos'), findsWidgets);
      expect(find.text('House Painting'), findsWidgets);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Block Ben Santos?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();

      expect(server.calls, contains('POST /users/9/block'));
      expect(find.byType(WorkerProfileScreen), findsNothing, reason: 'a blocked profile closes');
      await settle(tester);
    });

    testWidgets('your own profile has no Report or Block', (tester) async {
      await open(tester, const WorkerProfileScreen(), args: {'workerId': 9}, providers: providers(myId: 9));

      expect(find.text('Ben Santos'), findsWidgets);
      expect(find.byTooltip('More'), findsNothing);
      await settle(tester);
    });
  });

  group('Employer Profile', () {
    testWidgets('shows the business and lets you block it', (tester) async {
      await open(tester, const EmployerProfileScreen(), args: {'employerId': 12}, providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()..seedUser(me())),
        ChangeNotifierProvider<EmployerProfileProvider>(create: (_) => EmployerProfileProvider()),
      ]);

      expect(find.text('Reyes Hardware'), findsWidgets);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();

      expect(server.calls, contains('POST /users/12/block'));
      await settle(tester);
    });
  });

  group('New Post', () {
    List<ChangeNotifierProvider> providers() => [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()..seedUser(me())),
          ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
          ChangeNotifierProvider<CreditsProvider>(create: (_) => CreditsProvider()),
          ChangeNotifierProvider<WorkerProfileProvider>(create: (_) => WorkerProfileProvider(ApiClient())),
        ];

    Future<void> fillIn(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Electrician available this week');
      await tester.enterText(fields.at(1), 'Wiring, outlets and breakers. Urdaneta and nearby towns.');
      await tester.pump();
    }

    Finder postButton() => find.widgetWithText(ElevatedButton, 'Post for 5 Barya');

    testWidgets('with too little Barya it says so and opens the wallet', (tester) async {
      server.balance = 2;
      await open(tester, const ComposeCommunityPostScreen(), providers: providers());
      await fillIn(tester);

      await tester.ensureVisible(postButton());
      await tester.tap(postButton());
      await tester.pumpAndSettle();

      expect(find.text('Wallet Page'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /community')));
      await settle(tester);
    });

    testWidgets('asks first, then sends it for review', (tester) async {
      server.balance = 50;
      await open(tester, const ComposeCommunityPostScreen(), providers: providers());
      await fillIn(tester);

      await tester.ensureVisible(postButton());
      await tester.tap(postButton());
      await tester.pumpAndSettle();
      expect(find.text('Post This?'), findsOneWidget);
      expect(server.calls, isNot(contains('POST /community')), reason: 'nothing sent before Post');

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Post for 5 Barya')));
      await tester.pumpAndSettle();

      expect(server.calls, contains('POST /community'));
      expect(find.byType(ComposeCommunityPostScreen), findsNothing, reason: 'closes once sent');
      await settle(tester);
    });
  });

  group('Your Posts', () {
    List<ChangeNotifierProvider> providers() => [
          ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
        ];

    testWidgets('nothing posted says so', (tester) async {
      await open(tester, const MyCommunityPostsScreen(), providers: providers());
      expect(find.text('You have not posted anything yet.'), findsOneWidget);
    });

    testWidgets('lists your posts', (tester) async {
      server.mine = [
        {
          'id': 7, 'type': 'worker', 'title': 'Licensed electrician available for house wiring',
          'body': 'Ten years of experience. Own tools and transport.', 'photo_urls': const [],
          'status': 'pending', 'days_left': null, 'review_note': null, 'is_mine': true,
          'poster': {'id': 1, 'name': 'Ana Reyes', 'avatar': null, 'is_verified': true},
        },
      ];
      await open(tester, const MyCommunityPostsScreen(), providers: providers());
      expect(find.text('Licensed electrician available for house wiring'), findsOneWidget);
    });
  });

  group('Google sign-up password', () {
    testWidgets('declining the terms goes back and makes no account', (tester) async {
      await open(tester, const GooglePasswordScreen(), args: {'id_token': 'google-token', 'email': 'ana@gmail.com'}, providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ]);

      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(find.byType(GooglePasswordScreen), findsNothing);
      expect(server.calls, isNot(contains('POST /google-login')));
    });
  });

  group('Sign-up ID step', () {
    Finder done() => find.widgetWithText(ElevatedButton, 'Done');

    testWidgets('no Done until both photos are taken', (tester) async {
      await open(tester, const OnboardingVerificationScreen(), providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ]);
      expect(find.text('Tap to capture ID Photo', skipOffstage: false), findsWidgets);
      expect(find.text('Done', skipOffstage: false), findsNothing);
    });

    testWidgets('with both photos, Done waits for the confirmation', (tester) async {
      await open(
        tester,
        const OnboardingVerificationScreen(existingData: {
          'idType': 'UMID', 'idPhotoPath': '/tmp/id.jpg', 'idPhotoName': 'id.jpg',
          'selfiePhotoPath': '/tmp/selfie.jpg', 'selfiePhotoName': 'selfie.jpg', 'confirmed': false,
        }),
        providers: [ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider())],
      );

      await tester.ensureVisible(done());
      expect(tester.widget<ElevatedButton>(done()).onPressed, isNull);

      // On the box itself: the words hold the Terms and Privacy links.
      await tester.tapAt(tester.getTopLeft(find.byType(ConsentCheck)) + const Offset(11, 18));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(done()).onPressed, isNotNull);
    });

    testWidgets('with everything given, Done hands it back', (tester) async {
      await open(
        tester,
        const OnboardingVerificationScreen(existingData: {
          'idType': 'UMID', 'idPhotoPath': '/tmp/id.jpg', 'idPhotoName': 'id.jpg',
          'selfiePhotoPath': '/tmp/selfie.jpg', 'selfiePhotoName': 'selfie.jpg', 'confirmed': true,
        }),
        providers: [ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider())],
      );

      await tester.ensureVisible(done());
      await tester.tap(done());
      await tester.pumpAndSettle();

      expect(server.popped, isA<Map>());
      expect((server.popped as Map)['idType'], 'UMID');
    });
  });
}

class _Server implements HttpClientAdapter {
  final List<String> calls = [];
  int balance = 0;
  List<Map<String, dynamic>> mine = [];
  Object? popped;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls.add('${o.method} ${o.path}');
    switch (o.path) {
      case '/workers/9':
        return _json({'success': true, 'data': {
          'user_id': 9, 'name': 'Ben Santos', 'category': 'Painting', 'location': 'Urdaneta City, Pangasinan',
          'rating_avg': 4.5, 'rating_count': 2, 'availability_status': 'available',
          'skills': [{'name': 'House Painting'}], 'badges': [], 'experiences': [], 'certifications': [],
          'licenses': [], 'license_examinations': [], 'reviews': [], 'history': [],
          'jobs_completed': 3, 'jobs_unsuccessful': 0,
        }});
      case '/employers/12':
        return _json({'success': true, 'data': {
          'user_id': 12, 'name': 'Rosa Reyes', 'company_name': 'Reyes Hardware', 'location': 'Urdaneta City',
          'description': 'Hardware and construction supply.', 'rating_avg': 4.0, 'rating_count': 1,
          'badges': [], 'jobs': [], 'reviews': [], 'history': [], 'jobs_completed': 5, 'open_jobs_count': 0,
        }});
      case '/community/costs':
        return _json({'success': true, 'data': {'worker': 5, 'business': 15, 'days': 7}});
      case '/community/mine':
        return _json({'success': true, 'data': mine});
      case '/credits/wallet':
        return _json({'success': true, 'data': {'balance': balance, 'packages': [], 'costs': {}, 'comparison': []}});
    }
    if (o.method == 'POST' && o.path == '/community') {
      return _json({'success': true, 'data': {'id': 30, 'status': 'pending', 'title': 'x', 'type': 'worker'}}, 201);
    }
    if (o.method == 'POST' && o.path.endsWith('/block')) {
      return _json({'success': true, 'data': null, 'message': 'Blocked.'}, 201);
    }
    return _json({'success': true, 'data': []});
  }

  ResponseBody _json(Map<String, dynamic> body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}
