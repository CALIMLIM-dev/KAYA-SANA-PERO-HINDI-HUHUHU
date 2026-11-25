import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/providers/auth_provider.dart';

/*
    Signing out cancels the key on the server too. It used to delete the key
    first and then ask without it, so the old one stayed good for ninety days.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAdapter adapter;

  setUp(() {
    adapter = _RecordingAdapter();
    ApiClient.testAdapter = adapter;
  });

  tearDown(() => ApiClient.testAdapter = null);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

  test('signing out sends the key being given up', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'old-key'});

    await AuthProvider().logout();
    await settle();

    expect(adapter.keys['/logout'], 'Bearer old-key');
    expect(await ApiClient.getToken(), isNull);
  });

  test('a ban keeps its key: nothing is cancelled', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'old-key'});

    await AuthProvider().logout(revoke: false);
    await settle();

    expect(adapter.keys.containsKey('/logout'), isFalse);
  });

  test('signing straight into another account does not cancel the new key', () async {
    // The next account's key is already on the phone when the request goes.
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'new-key'});

    await ApiClient().revoke('old-key');

    expect(adapter.keys['/logout'], 'Bearer old-key');
    expect(await ApiClient.getToken(), 'new-key');
  });

  test('every other request still carries the key on the phone', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'new-key'});

    await ApiClient().get('/jobs');

    expect(adapter.keys['/jobs'], 'Bearer new-key');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  /// Path => the key the request went out with.
  final Map<String, Object?> keys = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys[options.path] = options.headers['Authorization'];

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
