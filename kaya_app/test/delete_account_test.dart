import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/widgets/delete_account_sheet.dart';

/*
    The delete-account sheet: nothing is sent until the password is typed
    and the box is ticked, the password goes with the request, and a
    refusal from the server is shown where the person is looking.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _DeleteAdapter adapter;

  setUp(() {
    adapter = _DeleteAdapter();
    ApiClient.testAdapter = adapter;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() => ApiClient.testAdapter = null);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DeleteAccountSheet()),
    ));
    await tester.pump();
  }

  ElevatedButton button(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete account'));

  testWidgets('the button waits for the password and the tick', (tester) async {
    await pump(tester);
    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.pump();
    expect(button(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(button(tester).onPressed, isNotNull);
  });

  testWidgets('a refusal from the server is shown on the sheet', (tester) async {
    adapter.reply = (422, 'You have 1 job with a worker on it. Finish or cancel it first.');
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(adapter.sentPassword, 'secret123');
    expect(adapter.method, 'DELETE');
    expect(find.text('You have 1 job with a worker on it. Finish or cancel it first.'), findsOneWidget);
    expect(find.byType(DeleteAccountSheet), findsOneWidget);
  });
}

class _DeleteAdapter implements HttpClientAdapter {
  (int, String) reply = (200, 'Your account has been deleted.');
  String? sentPassword;
  String? method;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    final sent = options.data is Map ? options.data as Map : jsonDecode(options.data as String) as Map;
    sentPassword = sent['password'] as String?;

    final (status, message) = reply;
    return ResponseBody.fromString(
      jsonEncode({'success': status < 400, 'data': null, 'message': message}),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
