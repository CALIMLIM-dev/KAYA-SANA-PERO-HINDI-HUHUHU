import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/features/applications/screens/view_applicants_screen.dart';
import 'package:kaya_app/features/profile/widgets/profile_views_popup.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';

import 'support/render_harness.dart';

/*
    One list for one job's applicants, and the top-up benefits around it:
    a free applicant is a name, a topped-up one the full card; the workers
    who fit and have not applied follow in the same list - named for a
    hirer who has topped up, counted for one who has not; and a worker who
    has topped up sees who viewed them and when a hirer opened their profile.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    ApiClient.testAdapter = server;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
  });

  tearDown(() => ApiClient.testAdapter = null);

  Map<String, dynamic> applicant(int id, String name, {bool premium = false, String status = 'pending'}) => {
        'application_id': id,
        'application_status': status,
        'worker_id': 100 + id,
        'worker_name': name,
        'worker_rating': premium ? 4.6 : 0,
        'worker_rating_count': premium ? 5 : 0,
        'is_verified': premium,
        'verification_state': premium ? 'verified' : 'unverified',
        'skills': ['Plumbing Repair', 'Leak Detection'],
        'category': 'Plumbing',
        'location': 'Nancayasan, Urdaneta City',
        'experience_label': premium ? '6 years' : null,
        'jobs_completed': premium ? 14 : 0,
        'is_premium': premium,
        'required_count': 2,
        'matched_count': 1,
        'matched_skills': ['plumbing repair'],
        'match_tier': 2,
        'applied_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      };

  Future<void> open(WidgetTester tester, Widget child, {Object? args}) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(412 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(settings: RouteSettings(arguments: args), builder: (_) => child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('one list: applied ranked, hired, then who else fits - counted when locked', (tester) async {
    server.applicants = [
      applicant(1, 'Ramon Villanueva', premium: true),
      applicant(2, 'Carlo Dela Cruz'),
      applicant(3, 'Pedro Bautista', status: 'accepted'),
      applicant(4, 'Liza Garcia', status: 'rejected'),
    ];
    server.matches = {'data': [], 'locked': true, 'match_count': 7};

    await open(tester, const ViewApplicantsScreen(), args: {'jobId': 9});

    expect(find.text('Applicants (2)'), findsOneWidget);
    expect(find.text('Hired (1)'), findsOneWidget);
    // No tabs any more.
    expect(find.byType(TabBar), findsNothing);

    // The topped-up applicant is laid out in full; the free one is a name.
    expect(find.text('Ramon Villanueva'), findsOneWidget);
    expect(find.text('6 years'), findsOneWidget);
    expect(find.text('Experience'), findsOneWidget);
    expect(find.text('Carlo Dela Cruz'), findsOneWidget);
    expect(find.textContaining('Required skills'), findsOneWidget, reason: 'only on the full card');

    // Who else fits: counted, with the way to see who.
    expect(find.text('Suggested Workers (7)'), findsOneWidget);
    expect(find.text('Top Up to View'), findsOneWidget);

    // Declined is folded away.
    expect(find.text('Liza Garcia'), findsNothing);
    await tester.tap(find.text('Show Rejected (1)'));
    await tester.pump();
    expect(find.text('Liza Garcia'), findsOneWidget);
  });

  testWidgets('a hirer who topped up sees the matches by name, minus those who applied', (tester) async {
    server.applicants = [applicant(1, 'Ramon Villanueva', premium: true)];
    server.matches = {
      'data': [
        {'user_id': 101, 'name': 'Ramon Villanueva', 'skills': [], 'verification_state': 'verified'},
        {'user_id': 205, 'name': 'Joy Mendoza', 'skills': ['Leak Detection'], 'verification_state': 'verified'},
      ],
      'locked': false,
      'match_count': 2,
    };

    await open(tester, const ViewApplicantsScreen(), args: {'jobId': 9});

    expect(find.text('Suggested Workers (1)'), findsOneWidget);
    expect(find.text('Joy Mendoza'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('profile views: a count when free, names and weeks once topped up', (tester) async {
    server.insights = {'unlocked': false, 'this_week': {'views': 4, 'people': 3}, 'weeks': null, 'viewers': null};
    await open(tester, Builder(builder: (context) => TextButton(
      onPressed: () => showProfileViewsPopup(context),
      child: const Text('open'),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('This week: 4 views from 3 people'), findsOneWidget);
    expect(find.text('Top Up'), findsOneWidget);
    Navigator.of(tester.element(find.text('Top Up'))).pop();
    await tester.pumpAndSettle();

    server.insights = {
      'unlocked': true,
      'this_week': {'views': 4, 'people': 3},
      'weeks': [for (var i = 0; i < 8; i++) {'week_of': '2026-08-${(i + 1) * 3}', 'views': i, 'people': i}],
      'viewers': [
        {'id': 3, 'name': 'Maria Santos', 'viewed_on': DateTime.now().toIso8601String(), 'verification_state': 'verified'},
      ],
    };
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Top Up'), findsNothing);
  });

  testWidgets('a waiting application says when the hirer opened the profile', (tester) async {
    await open(tester, Scaffold(body: ApplicationCard(
      application: {
        'id': 5,
        'status': 'pending',
        'seen_by_hirer_on': DateTime.now().toIso8601String().substring(0, 10),
        'job': {'id': 9, 'title': 'Fix leaking pipes', 'employer': {'id': 3, 'name': 'Maria Santos'}},
      },
      onChanged: () async {},
    )));

    expect(find.text('The employer viewed your profile today'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}

class _FakeServer implements HttpClientAdapter {
  List<Map<String, dynamic>> applicants = const [];
  Map<String, dynamic> matches = const {'data': [], 'locked': false, 'match_count': 0};
  Map<String, dynamic> insights = const {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    Object body = {'success': true, 'data': null};

    if (path.endsWith('/applicants')) body = {'success': true, 'data': applicants};
    if (path.endsWith('/matches')) body = {'success': true, ...matches};
    if (RegExp(r'/jobs/\d+$').hasMatch(path)) {
      body = {'success': true, 'data': {'id': 9, 'title': 'Fix leaking pipes', 'status': 'open', 'workers_needed': 1}};
    }
    if (path.endsWith('/profile-views/insights')) body = {'success': true, 'data': insights};

    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
