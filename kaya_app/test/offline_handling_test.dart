import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/network/connection_status.dart';
import 'package:kaya_app/core/widgets/offline_notice.dart';
import 'package:kaya_app/data/services/api_client.dart';

/*
    Losing the connection is a thing the app can name.

    A request that never reached the server used to come back as "Something
    went wrong — no reply from the server (connectionError)", which is what
    was appearing in a red box under the home feed. It was also
    indistinguishable from the server refusing something, so no screen could
    tell the two apart or offer the one thing that helps.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SwitchableAdapter adapter;

  setUp(() {
    adapter = _SwitchableAdapter();
    ApiClient.testAdapter = adapter;
    ConnectionStatus.instance.reset();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    ApiClient.testAdapter = null;
    ConnectionStatus.instance.reset();
  });

  group('the client tells the network apart from the server', () {
    test('no route out is an offline failure, not "something went wrong"',
        () async {
      adapter.failure = DioExceptionType.connectionError;

      final error = await _capture(() => ApiClient().get('/jobs'));

      expect(error, isA<ApiException>());
      final api = error as ApiException;
      expect(api.isOffline, isTrue);
      expect(api.message, 'No internet connection.');
      // There was no response, so there is no status to report.
      expect(api.status, isNull);
      expect(ConnectionStatus.instance.isOffline, isTrue);
    });

    test('a timeout is the same failure', () async {
      adapter.failure = DioExceptionType.connectionTimeout;

      final error = await _capture(() => ApiClient().get('/jobs'));

      expect((error as ApiException).isOffline, isTrue);
      expect(ConnectionStatus.instance.isOffline, isTrue);
    });

    test('a socket failure is the same failure', () async {
      adapter.socketFailure = true;

      final error = await _capture(() => ApiClient().get('/jobs'));

      expect((error as ApiException).isOffline, isTrue);
    });

    test('a refusal from the server is not offline', () async {
      adapter.status = 422;
      adapter.message = 'Choose the kind of work you do.';

      final error = await _capture(() => ApiClient().get('/jobs'));

      final api = error as ApiException;
      expect(api.isOffline, isFalse);
      expect(api.message, 'Choose the kind of work you do.');
      // The server answered, so the connection is plainly fine.
      expect(ConnectionStatus.instance.isOffline, isFalse);
    });

    test('a reply of any kind clears an earlier offline mark', () async {
      adapter.failure = DioExceptionType.connectionError;
      await _capture(() => ApiClient().get('/jobs'));
      expect(ConnectionStatus.instance.isOffline, isTrue);

      // Not a success - a refusal. It still proves the server was reached.
      adapter.failure = null;
      adapter.status = 403;
      adapter.message = 'Verify your account first.';
      await _capture(() => ApiClient().get('/jobs'));

      expect(ConnectionStatus.instance.isOffline, isFalse);
    });
  });

  group('what the app shows', () {
    testWidgets('the blocking notice names what failed and offers a retry',
        (tester) async {
      var retried = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OfflineNotice(what: 'jobs', onRetry: () => retried++),
        ),
      ));

      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        find.textContaining('could not load jobs'),
        findsOneWidget,
        reason: 'It should say what did not load, not just that something did.',
      );

      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('no retry button when there is nothing to retry',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: OfflineNotice()),
      ));

      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('the bar appears and goes without disturbing the screen',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ConnectionBanner(
          child: Scaffold(body: Center(child: Text('the feed'))),
        ),
      ));

      expect(find.text('the feed'), findsOneWidget);
      expect(find.text('No internet connection'), findsNothing);

      final before = tester.getTopLeft(find.text('the feed'));

      ConnectionStatus.instance.markOffline();
      await tester.pump();

      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        find.text('the feed'),
        findsOneWidget,
        reason: 'Losing signal must not take away content already on screen.',
      );

      ConnectionStatus.instance.markOnline();
      await tester.pump();

      expect(find.text('No internet connection'), findsNothing);
      expect(
        tester.getTopLeft(find.text('the feed')),
        before,
        reason: 'The bar must give its height back when it goes.',
      );
    });
  });
}

/// Runs [body] and returns whatever it threw.
Future<Object> _capture(Future<void> Function() body) async {
  try {
    await body();
  } catch (e) {
    return e;
  }
  fail('Expected the request to fail.');
}

/*
    One adapter that can be either half of the problem: a request that never
    lands, or a server that answers with a refusal.
*/
class _SwitchableAdapter implements HttpClientAdapter {
  /// Set to fail the request before it reaches anything.
  DioExceptionType? failure;

  /// Fails with a SocketException carried in `error`, the way a dead
  /// interface arrives rather than a Dio timer.
  bool socketFailure = false;

  int status = 200;
  String message = 'Success';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (socketFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const SocketException('Network is unreachable'),
      );
    }

    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }

    return ResponseBody.fromString(
      jsonEncode({
        'success': status < 400,
        'data': null,
        'message': message,
      }),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
