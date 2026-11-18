import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/moderation/widgets/report_sheet.dart';

import 'support/render_harness.dart';

/*
    A report reached admin as "Spam" when the person said they picked
    Harassment. Whatever reason is picked must be the one sent.
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

  for (final reason in _FakeServer.reasons) {
    testWidgets('picking ${reason['label']} sends ${reason['code']}', (tester) async {
      RenderHarness.stubPlatformChannels(tester);
      tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ReportSheet.show(context, reportedId: 9, reportedName: 'Juan', subjectType: 'message'),
              child: const Text('report'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose a reason'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(reason['label']!).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'He kept sending threats after I said no.');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(server.bodies['/reports']?['reason_code'], reason['code']);
    });
  }
}

class _FakeServer implements HttpClientAdapter {
  static const reasons = [
    {'code': 'harassment', 'label': 'Harassment or threats'},
    {'code': 'scam', 'label': 'Scam or fraud'},
    {'code': 'spam', 'label': 'Spam'},
    {'code': 'other', 'label': 'Something else'},
  ];

  final Map<String, Map<String, dynamic>> bodies = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.data is Map) bodies[options.path] = (options.data as Map).cast<String, dynamic>();

    final data = options.path == '/report-reasons'
        ? {'reasons': [for (final r in reasons) {'code': r['code'], 'label': r['label'], 'description': ''}]}
        : {'id': 1};
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data, 'message': 'OK'}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
