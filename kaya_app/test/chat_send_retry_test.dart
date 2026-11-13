import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/providers/messaging_provider.dart';

/*
    Chat on slow data.

    A send that died on the way used to be marked failed at once, and Retry
    posted it again - a second copy if the first had reached the server.
    Now each message carries a key, the same on every try, and a dropped
    connection is retried on its own before anything is marked failed.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MessagingProvider.retryDelays = const [Duration.zero, Duration.zero, Duration.zero];
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
  });
  tearDown(() => ApiClient.testAdapter = null);

  test('a dropped connection is retried with the same key, and the message sends', () async {
    final server = _Server(failFirst: 2);
    ApiClient.testAdapter = server;

    final sent = await MessagingProvider().sendMessage(5, 'Darating ako bukas ng 8.');

    expect(sent, isTrue);
    expect(server.sends.length, 3, reason: 'two drops, then through');
    expect(server.sends.map((b) => b['client_id']).toSet().length, 1, reason: 'one key for every try');
    expect(server.sends.first['client_id'], isNotEmpty);
  });

  test('a refusal is not retried', () async {
    final server = _Server(refuse: true);
    ApiClient.testAdapter = server;

    final sent = await MessagingProvider().sendMessage(5, 'Tawagan mo ako 09171234567');

    expect(sent, isFalse);
    expect(server.sends.length, 1);
  });

  test('Retry on a failed message reuses its key', () async {
    final server = _Server(failFirst: 99);
    ApiClient.testAdapter = server;
    final chat = MessagingProvider();
    await chat.fetchMessages(5);

    expect(await chat.sendMessage(5, 'Okay po'), isFalse);
    final failed = chat.messages.firstWhere((m) => m['status'] == 'failed');
    final firstKey = server.sends.first['client_id'];

    server.failFirst = 0;
    expect(await chat.retryMessage(5, failed['id'] as int), isTrue);
    expect(server.sends.last['client_id'], firstKey);
  });
}

class _Server implements HttpClientAdapter {
  _Server({this.failFirst = 0, this.refuse = false});

  int failFirst;
  final bool refuse;
  final List<Map<String, dynamic>> sends = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method == 'POST' && o.path.endsWith('/messages')) {
      sends.add(Map<String, dynamic>.from(o.data as Map));
      if (refuse) {
        return _json({'success': false, 'data': null, 'message': 'Remove the phone number to send this.'}, 422);
      }
      if (sends.length <= failFirst) {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionTimeout);
      }
      return _json({
        'success': true,
        'data': {'id': 900 + sends.length, 'client_id': o.data['client_id'], 'message_text': o.data['message_text'], 'sender_id': 1},
        'message': 'Message sent successfully',
      }, 201);
    }
    return _json({'success': true, 'data': {'data': [], 'next_cursor': null}}, 200);
  }

  ResponseBody _json(Map<String, dynamic> body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}
