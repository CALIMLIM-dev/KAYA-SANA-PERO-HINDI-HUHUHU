import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/employer/screens/roster_screen.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';

import 'support/render_harness.dart';

/*
    Hired Workers opened to "This Screen Could Not Open" from the Active
    section, for every job with a hire (19 Oct 2026).

    The server sends rating_avg as "4.50" - a decimal column is a string in
    JSON - and the screen cast it straight to a number. Found by replaying
    the server's own answers through every screen Active opens.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiClient.testAdapter = _Roster();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
  });

  tearDown(() => ApiClient.testAdapter = null);

  testWidgets('a rating sent as text opens the screen', (tester) async {
    RenderHarness.stubPlatformChannels(tester);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MaterialApp(home: RosterScreen(jobId: 5)),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.textContaining('4.5'), findsWidgets);
  });
}

class _Roster implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = options.path.endsWith('/jobs/5/roster')
        ? {
            'success': true,
            'data': {
              'job': {'id': 5, 'title': 'Pipe the whole house', 'status': 'open', 'workers_needed': 3, 'workers_filled': 1},
              'hires': [
                {
                  'application_id': 6,
                  'worker_id': 4,
                  'name': 'Juan Dela Cruz',
                  'avatar': null,
                  'is_verified': true,
                  'verification_state': 'verified',
                  'rating_avg': '4.50',
                  'rating_count': 2,
                  'status': 'accepted',
                  'completion': {'you_confirmed': false, 'they_confirmed': false, 'complete': false},
                  'hire_actions': {'can_cancel': true, 'cancel': null, 'can_dispute': false, 'disputed': false},
                  'conversation_id': 2,
                },
              ],
            },
          }
        : {'success': true, 'data': []};

    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
