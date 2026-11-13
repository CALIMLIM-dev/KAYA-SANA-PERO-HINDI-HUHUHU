import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/moderation/widgets/block_user.dart';

import 'support/render_harness.dart';

/*
    Blocking from the app: the confirm step, and Settings' list to unblock.
    The hiding itself is the server's (BlockUserTest).
*/
void main() {
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
  });
  tearDown(() => ApiClient.testAdapter = null);

  Future<void> pump(WidgetTester tester, Widget child) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('Block asks first, and only Block sends it', (tester) async {
    bool? result;
    await pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await confirmBlock(context, userId: 8, name: 'Ben Santos'),
        child: const Text('go'),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Block Ben Santos?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.calls, isEmpty);
    expect(result, isFalse);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(server.calls, ['POST /users/8/block']);
    expect(result, isTrue);
  });

  testWidgets('Blocked Accounts lists who is blocked, and Unblock removes them', (tester) async {
    await pump(tester, const BlockedAccounts());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ana Reyes'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));

    expect(server.calls, contains('DELETE /users/3/block'));
    expect(find.text('Ana Reyes'), findsNothing);
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
  });
}

class _Server implements HttpClientAdapter {
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    Object data = [];
    if (o.method == 'GET' && o.path == '/blocked-users') {
      data = [{'id': 3, 'name': 'Ana Reyes', 'blocked_at': '2026-11-13T02:00:00Z'}];
    } else {
      calls.add('${o.method} ${o.path}');
      data = {};
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data, 'message': 'Done.'}),
      o.method == 'POST' ? 201 : 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
