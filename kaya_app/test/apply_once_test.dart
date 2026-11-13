import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/job_details_screen.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    QA finding 9: two quick taps on Apply sent two applications.

    The button's busy flag was set only after the verification check had
    been awaited, so a second tap in that gap went through as well. The
    server refuses the duplicate (unique index, one transaction), but the
    worker saw an error after applying successfully.

    The job is the server's real reply to a worker viewing an open job
    (test/fixtures/job_worker_view.json).
*/
void main() {
  testWidgets('two quick taps on Apply send one application', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = _Server();
    ApiClient.testAdapter = server;
    addTearDown(() => ApiClient.testAdapter = null);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final auth = AuthProvider()
      ..seedUser({'id': 2, 'name': 'Juan Dela Cruz', 'is_verified': true, 'worker_profile_exists': true});

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const JobDetailsScreen(),
          settings: const RouteSettings(arguments: {'jobId': 1}),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final apply = find.textContaining('Apply Now');
    expect(apply, findsOneWidget, reason: 'the job page must show Apply before the taps mean anything');

    // Two taps before the screen has drawn again.
    await tester.tap(apply);
    await tester.tap(apply);
    await tester.pump(const Duration(seconds: 2));

    expect(server.applyCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}

class _Server implements HttpClientAdapter {
  int applyCalls = 0;
  final _job = File('test/fixtures/job_worker_view.json').readAsStringSync();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    String body = jsonEncode({'success': true, 'data': []});
    if (o.path == '/jobs/1' && o.method == 'GET') body = _job;
    if (o.path == '/jobs/1/apply') {
      applyCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      body = jsonEncode({'success': true, 'data': {'id': 9, 'status': 'pending'}, 'message': 'Applied'});
    }
    return ResponseBody.fromString(body, 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
