import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/moderation/widgets/ban_lock.dart';

/*
    Phase 8: a permanent ban locks the app on a pop-up that cannot be closed.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> stored;
  late _FakeServer server;

  setUp(() {
    stored = {};
    server = _FakeServer();
    ApiClient.testAdapter = server;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, dynamic>();
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return stored[key];
          case 'write':
            stored[key!] = args['value'] as String;
            return null;
          case 'delete':
            stored.remove(key);
            return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    ApiClient.testAdapter = null;
    ApiClient.sessionOverride = null;
    ApiClient.onBanned = null;
  });

  test('a ban answer on this phone\'s session calls onBanned; a suspension does not', () async {
    stored['auth_token'] = 'live-token';
    String? banned;
    ApiClient.onBanned = (t) => banned = t;

    server.until = '2026-12-01T00:00:00Z';
    await expectLater(ApiClient().get('/jobs'), throwsA(anything));
    expect(banned, isNull, reason: 'a 7-day suspension is not locked');

    server.until = null;
    await expectLater(ApiClient().get('/jobs'), throwsA(anything));
    expect(banned, 'live-token');
  });

  Future<void> openLock(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => BanLock.showIfKept(context), child: const Text('Sign In')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }

  testWidgets('a kept ban opens the lock, and it cannot be closed', (tester) async {
    stored['ban_lock_token'] = 'ban-token';
    server.until = null;
    await openLock(tester);

    expect(find.text('Account Status'), findsOneWidget);
    expect(find.text('Appeal'), findsOneWidget);
    expect(find.text('Message Support'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    // Outside tap and back both leave it where it is.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Message Support'), findsOneWidget);
    expect(ApiClient.sessionOverride, 'ban-token');
  });

  testWidgets('a lifted ban clears itself and shows nothing', (tester) async {
    stored['ban_lock_token'] = 'ban-token';
    server.suspended = false;
    await openLock(tester);

    expect(find.text('Message Support'), findsNothing);
    expect(stored.containsKey('ban_lock_token'), isFalse);
    expect(ApiClient.sessionOverride, isNull);
  });
}

class _FakeServer implements HttpClientAdapter {
  bool suspended = true;
  String? until;

  Map<String, dynamic> get _state => {'is_suspended': suspended, 'suspended_reason': 'Scam or fraud', 'suspended_until': until};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/check-status')) {
      return _json({'success': true, 'data': _state}, 200);
    }
    return _json({'success': false, 'data': _state, 'message': 'Account suspended'}, 403);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}
