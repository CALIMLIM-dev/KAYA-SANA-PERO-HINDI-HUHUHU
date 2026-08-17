import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/features/applications/screens/view_applicants_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    The app's own logic, driven against a live server.

    Everything verified so far has been HTTP: the API returns the right thing.
    This asks the next question — given that response, does the app show the
    right control? That gap is where every bug this week actually lived. The
    server was correct about completion and three separate screens still drew a
    finished job, because each decided for itself what the response meant.

    So this creates real records over HTTP, mounts the real screens with the
    real providers, and asserts on what a person would see.

    Needs a server. Run with:
      flutter test test/app_logic_test.dart \
        --dart-define=API_BASE_URL=http://127.0.0.1:8123

    Skips itself when nothing is listening, rather than reporting a page of
    failures that only mean the backend is off.
*/

const String _base =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8123');

/// The token the stubbed secure storage hands to ApiClient. Swapping this
/// between pumps is how one test looks at the same job as both parties.
String? _activeToken;

// ── plain HTTP, outside the widget layer ─────────────────────────────────────

Future<Map<String, dynamic>> _call(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(
        method, Uri.parse('$_base/api/v1$path'));
    req.headers.set('Accept', 'application/json');
    req.headers.set('ngrok-skip-browser-warning', '1');
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    final decoded = text.isEmpty ? {} : jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  } finally {
    client.close(force: true);
  }
}

/// Multipart, because posting a job requires at least one photo.
Future<Map<String, dynamic>> _postJob(String token, Map<String, String> fields) async {
  final client = HttpClient();
  try {
    const boundary = '----kayaLogicProbe';
    final req = await client.postUrl(Uri.parse('$_base/api/v1/jobs'));
    req.headers.set('Accept', 'application/json');
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

    final buf = StringBuffer();
    fields.forEach((k, v) {
      buf.write('--$boundary\r\n');
      buf.write('Content-Disposition: form-data; name="$k"\r\n\r\n$v\r\n');
    });
    buf.write('--$boundary\r\n');
    buf.write('Content-Disposition: form-data; name="photos[]"; '
        'filename="p.png"\r\nContent-Type: image/png\r\n\r\n');

    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

    req.add(utf8.encode(buf.toString()));
    req.add(png);
    req.add(utf8.encode('\r\n--$boundary--\r\n'));

    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _serverUp() async {
  try {
    await _call('POST', '/login',
        body: {'email': 'probe@none.invalid', 'password': 'x'});
    return true;
  } catch (_) {
    return false;
  }
}

/*
    Let real requests out.

    TestWidgetsFlutterBinding installs an HttpOverrides that answers every
    request with 400 and never touches the network — the right default for a
    unit test, and the exact opposite of what this file is for. Clearing it
    restores the real client for both the setup calls below and the app's own
    fetches, which go through Dio and the same HttpClient underneath.

    Re-cleared before each mount because the binding reinstalls it per test.
*/
void _allowRealNetwork() => HttpOverrides.global = null;

void main() {
  late String workerToken, employerToken;
  late int jobId, applicationId;
  var ready = false;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _allowRealNetwork();
    if (!await _serverUp()) return;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    Future<String> register(String who) async {
      final r = await _call('POST', '/register', body: {
        'name': 'Logic $who',
        'email': 'logic.$who.$stamp@demo.kaya.local',
        'password': 'Password123!',
        'password_confirmation': 'Password123!',
        'terms_accepted': true,
      });
      return (r['data'] as Map)['token'] as String;
    }

    workerToken = await register('worker');
    employerToken = await register('employer');


    final cats = (await _call('GET', '/categories', token: workerToken))['data'];
    final catId = ((cats is List ? cats : (cats as Map)['data']) as List)
        .first['id'] as int;
    final locs = (await _call('GET', '/locations/search?q=Urdaneta',
        token: workerToken))['data'];
    final locId = ((locs is List ? locs : (locs as Map)['data']) as List)
        .first['id'] as int;

    await _call('PUT', '/worker/profile',
        token: workerToken,
        body: {'city': 'Urdaneta City', 'location_id': locId});
    await _call('POST', '/worker/skills',
        token: workerToken,
        body: {'skill_name': 'Carpentry', 'category_id': catId});
    await _call('POST', '/worker/profile/complete-setup', token: workerToken);

    await _call('POST', '/employer-profile', token: employerToken, body: {
      'employer_type': 'individual',
      'location': 'Urdaneta City',
      'location_id': locId,
    });
    await _call('POST', '/employer-profile/complete-setup', token: employerToken);

    final job = await _postJob(employerToken, {
      'title': 'Logic probe job',
      'description': 'Driving the real screens.',
      'category_id': '$catId',
      'budget_min': '900',
      'budget_max': '1200',
      'budget_period': 'daily',
      'location': 'Urdaneta City',
      'location_id': '$locId',
      'start_date': '2026-09-01',
    });
    jobId = (job['data'] as Map)['id'] as int;

    await _call('POST', '/jobs/$jobId/apply', token: workerToken, body: {});
    final applicants =
        (await _call('GET', '/jobs/$jobId/applicants', token: employerToken))['data']
            as List;
    applicationId = applicants.first['application_id'] as int;
    await _call('PATCH', '/applications/$applicationId/accept',
        token: employerToken);

    ready = true;
  });

  tearDownAll(() async {
    if (!ready) return;
    // Leave nothing behind. The probe account owns everything it made.
    await _call('DELETE', '/jobs/$jobId', token: employerToken);
  });

  /// Mounts a screen with real providers and lets its own fetch actually run.
  ///
  /// The screens fetch in a post-frame callback. Under the test's fake clock a
  /// real request never resolves, so the pump has to happen inside runAsync.
  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    required String token,
    Object? routeArgs,
    bool worker = true,
  }) async {
    _activeToken = token;
    _allowRealNetwork();
    RenderHarness.stubPlatformChannels(tester);
    _stubTokenRead(tester);

    await RenderHarness.loadFonts(tester);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider();
    final apps = ApplicationProvider();
    final jobs = JobProvider();
    final mode = AppModeProvider();

    await tester.runAsync(() async {
      await auth.fetchMe();
      mode.reconcile(
        hasWorker: worker,
        hasEmployer: !worker,
      );

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: apps),
          ChangeNotifierProvider.value(value: jobs),
          ChangeNotifierProvider.value(value: mode),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (_) => screen,
          ),
          onGenerateRoute: (s) => MaterialPageRoute(
            settings: RouteSettings(name: s.name, arguments: routeArgs),
            builder: (_) => screen,
          ),
          initialRoute: '/',
        ),
      ));

      // The screen's own fetch is a real request; give it room to land.
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('worker sees mark complete on an accepted hire, not a review',
      (tester) async {
    if (!ready) return;

    await open(tester, const ApplicationsScreen(), token: workerToken);

    expect(find.text('Mark as complete'), findsWidgets,
        reason: 'an accepted hire must offer completion to the worker');
    expect(find.text('Review employer'), findsNothing,
        reason: 'reviewing before the work is finished must not be offered');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('after the employer confirms, the worker is told to confirm too',
      (tester) async {
    if (!ready) return;

    await _call('PATCH', '/applications/$applicationId/complete',
        token: employerToken);

    await open(tester, const ApplicationsScreen(), token: workerToken);

    expect(
      find.textContaining('marked this done'),
      findsWidgets,
      reason: 'the worker must be told the other side is waiting on them',
    );
    expect(find.text('Review employer'), findsNothing,
        reason: 'one side alone does not unlock reviewing',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('once both confirm, review replaces mark complete',
      (tester) async {
    if (!ready) return;

    await _call('PATCH', '/applications/$applicationId/complete',
        token: workerToken);

    await open(tester, const ApplicationsScreen(), token: workerToken);

    expect(find.text('Review employer'), findsWidgets,
        reason: 'a finished job must offer the review');
    expect(find.text('Mark as complete'), findsNothing,
        reason: 'completion must stop being offered once it is done');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('the applicant card offers messaging and a review to the employer',
      (tester) async {
    if (!ready) return;

    await open(
      tester,
      const ViewApplicantsScreen(),
      token: employerToken,
      routeArgs: {'jobId': jobId},
      worker: false,
    );

    expect(find.text('Message'), findsWidgets,
        reason: 'an accepted applicant must be reachable from their card');
    expect(find.text('Review'), findsWidgets,
        reason: 'a finished hire must be reviewable from the applicant list');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// Feeds ApiClient a real bearer token without a device keystore.
void _stubTokenRead(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return _activeToken;
      if (call.method == 'readAll') {
        return <String, String>{if (_activeToken != null) 'auth_token': _activeToken!};
      }
      return null;
    },
  );
}
