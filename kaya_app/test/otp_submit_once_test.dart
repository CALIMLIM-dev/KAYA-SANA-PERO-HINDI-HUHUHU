import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/widgets/otp_field.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/auth/screens/verify_reset_code_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';

import 'support/render_harness.dart';

/*
    QA finding 3: the code box sent the code more than once.

    It submitted on every change to its value while it held six digits -
    a cursor move, the keyboard finishing, an extra key press - and the
    reset screen sent each of those to the server, every one counted
    against the same limit as signing in.
*/
void main() {
  testWidgets('a finished code is submitted once, not on every change after', (tester) async {
    final code = TextEditingController();
    var submitted = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OtpField(controller: code, onCompleted: (_) => submitted++)),
    ));

    code.text = '482917';
    await tester.pump();
    expect(submitted, 1);

    // The keyboard moving the cursor, or finishing composing: same code.
    code.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    code.value = code.value.copyWith(composing: TextRange.empty);
    await tester.pump();
    expect(submitted, 1, reason: 'the same code was sent again');

    // A corrected code is a new one, and is sent.
    code.text = '48291';
    await tester.pump();
    code.text = '482918';
    await tester.pump();
    expect(submitted, 2);
  });

  testWidgets('the reset screen sends the code once while one check is still out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = _SlowServer();
    ApiClient.testAdapter = server;
    addTearDown(() => ApiClient.testAdapter = null);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const VerifyResetCodeScreen(),
          settings: const RouteSettings(arguments: {'email': 'maria@example.com'}),
        ),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text = '482917';
    await tester.pump();
    // While the first check is out: a cursor move, then the Verify button.
    field.controller!.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    await tester.tap(find.text('Verify Code'), warnIfMissed: false);
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    expect(server.verifyCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}

/// Answers /verify-reset-code after a second, so overlapping sends show.
class _SlowServer implements HttpClientAdapter {
  int verifyCalls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.path.endsWith('/verify-reset-code')) verifyCalls++;
    await Future<void>.delayed(const Duration(seconds: 1));
    return ResponseBody.fromString(
      jsonEncode({'success': false, 'data': null, 'message': 'Invalid or expired reset code. Please request a new one.'}),
      422,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
