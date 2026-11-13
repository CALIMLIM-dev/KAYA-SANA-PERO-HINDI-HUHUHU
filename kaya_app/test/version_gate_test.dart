import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/version_gate.dart';
import 'package:kaya_app/data/services/api_client.dart';

/*
    The update prompt is asked on every return to the foreground, so a phone
    that is never closed still hears about updates. The optional one used to
    reappear on every resume after being dismissed. Now a decline stands until
    the version changes. A required update is never remembered.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _VersionAdapter adapter;

  setUp(() {
    adapter = _VersionAdapter();
    ApiClient.testAdapter = adapter;
    VersionGate.reset();
  });

  tearDown(() {
    ApiClient.testAdapter = null;
    VersionGate.reset();
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    // No device keystore in a test; the token read must answer, not throw,
    // or the request never leaves and the gate fails open.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    return ctx;
  }

  testWidgets('a dismissed optional update is not asked again this session',
      (tester) async {
    adapter.latest = '9.9.9';
    adapter.required = false;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsNothing);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsNothing);
  });

  testWidgets('a newer version asks again', (tester) async {
    adapter.latest = '9.9.9';
    adapter.required = false;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    adapter.latest = '9.9.10';
    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Update Available'), findsOneWidget);
  });

  testWidgets('a required update is asked every time', (tester) async {
    adapter.latest = '9.9.9';
    adapter.required = true;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Update Needed'), findsOneWidget);
  });

  /*
      Update Now opens the store or download page outside the app. The app
      never downloads and installs an APK itself: Google Play rejects that.
  */
  testWidgets('Update Now opens the download page, it does not install',
      (tester) async {
    final opened = <Uri>[];
    VersionGate.openUrl = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => VersionGate.openUrl = (uri) async => false);

    adapter.latest = '9.9.9';
    adapter.required = false;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://example.test/download')]);
    expect(find.text('Update Available'), findsNothing,
        reason: 'an optional update closes once the page is open');
  });

  testWidgets('a required update stays up after opening the page',
      (tester) async {
    VersionGate.openUrl = (uri) async => true;
    adapter.latest = '9.9.9';
    adapter.required = true;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    expect(find.text('Update Needed'), findsOneWidget);
  });

  testWidgets('a page that will not open says so', (tester) async {
    VersionGate.openUrl = (uri) async => false;
    adapter.latest = '9.9.9';
    adapter.required = false;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the update page.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('a current build is left alone', (tester) async {
    adapter.latest = null;
    final ctx = await pump(tester);

    VersionGate.check(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}

/// Answers /app-version. A null `latest` means the build is current.
class _VersionAdapter implements HttpClientAdapter {
  String? latest;
  bool required = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'latest_version': latest ?? '0.0.0',
          'download_url': 'https://example.test/download',
          'supported': !required,
          'update_required': required,
          'update_available': latest != null && !required,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
