import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/applications/widgets/hire_controls.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';

import 'support/render_harness.dart';

/*
    Cancel hire, answering a request to cancel, and "it didn't happen",
    as one widget reading the server's hire_actions on every card.
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

  Future<void> render(WidgetTester tester, Map<String, dynamic> actions) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppModeProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (_) => HireControls.maybe(
                  actions: actions,
                  applicationId: 7,
                  otherName: 'Maria Santos',
                  otherId: 3,
                  onChanged: () async {},
                ) ??
                const Text('nothing'),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a live hire can be cancelled with a reason', (tester) async {
    await render(tester, {'can_cancel': true, 'can_dispute': false, 'disputed': false, 'cancel': null});

    await tester.tap(find.text('Cancel Job'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(ElevatedButton, 'Cancel Job');
    expect(tester.widget<ElevatedButton>(send).onPressed, isNull, reason: 'a reason first');

    await tester.tap(find.text('Could Not Agree on Pay'));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(server.calls, contains('POST /applications/7/cancel'));
    expect(server.bodies['/applications/7/cancel']?['reason'], 'pay');
  });

  testWidgets('your own request says when it cancels and can be taken back', (tester) async {
    await render(tester, {
      'can_cancel': false,
      'cancel': {'mine': true, 'reason': 'Could not agree on pay', 'cancels_at': '2026-10-16T07:00:00Z'},
    });

    expect(find.text('You asked to cancel. Reason: Could not agree on pay.'), findsOneWidget);
    expect(find.textContaining('if Maria Santos does not answer'), findsOneWidget);

    await tester.tap(find.text('Undo Request'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(server.calls, contains('DELETE /applications/7/cancel'));
  });

  testWidgets("the other side's request can be agreed to", (tester) async {
    await render(tester, {
      'cancel': {'mine': false, 'reason': 'Schedule conflict', 'note': 'I got sick.', 'cancels_at': '2026-10-16T07:00:00Z'},
    });

    expect(find.text('Maria Santos asked to cancel. Reason: Schedule conflict.'), findsOneWidget);
    expect(find.text('"I got sick."'), findsOneWidget);

    await tester.tap(find.text('Agree to Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Agree to Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(server.calls, contains('POST /applications/7/cancel/agree'));
  });

  testWidgets("it didn't happen is offered when the other side marked it done", (tester) async {
    await render(tester, {'can_cancel': true, 'can_dispute': true});

    expect(find.text('Report a Problem'), findsOneWidget);
    expect(find.text('Cancel Job'), findsOneWidget);
  });

  testWidgets('a disputed hire says who decides, and a finished one shows nothing', (tester) async {
    await render(tester, {'disputed': true});
    expect(find.textContaining('A problem was reported'), findsOneWidget);

    await render(tester, {'can_cancel': false, 'can_dispute': false, 'disputed': false, 'cancel': null});
    expect(find.text('nothing'), findsOneWidget);
  });
}

class _FakeServer implements HttpClientAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    if (options.data is Map) bodies[options.path] = (options.data as Map).cast<String, dynamic>();

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {'outcome': 'requested'}, 'message': 'Asked.'}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
