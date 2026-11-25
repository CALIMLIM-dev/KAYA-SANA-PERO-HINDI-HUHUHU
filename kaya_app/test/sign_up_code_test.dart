import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/widgets/otp_field.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/auth/screens/signup_screen.dart';
import 'package:kaya_app/features/auth/screens/verify_reset_code_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';

import 'support/render_harness.dart';

/*
    Reported: any Gmail could be signed up with by typing it. Sign Up sends a
    code first, and only the code makes the account.
*/
void main() {
  late _Server server;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await RenderHarness.loadFonts(tester);
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
    addTearDown(() => ApiClient.testAdapter = null);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        home: const SignupScreen(),
        onGenerateRoute: (s) => MaterialPageRoute(
          settings: s,
          builder: (_) => s.name == '/verify-reset-code'
              ? const VerifyResetCodeScreen()
              : Scaffold(body: Text('Page ${s.name}')),
        ),
      ),
    ));
    await settle(tester);
  }

  /// Fills the form, accepts the terms, and presses Sign Up.
  Future<void> signUp(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'maria.santos@gmail.com');
    await tester.enterText(fields.at(1), 'tambayan42rocks!');
    await tester.enterText(fields.at(2), 'tambayan42rocks!');
    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop(true);
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await settle(tester);
  }

  Future<void> typeCode(WidgetTester tester, String code) async {
    tester.widget<OtpField>(find.byType(OtpField)).controller.text = code;
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('Sign Up asks for the code and makes no account', (tester) async {
    await open(tester);
    await signUp(tester);

    expect(server.paths, ['/register/code']);
    expect(find.text('Verify Code'), findsWidgets);
    expect(find.textContaining('maria.santos@gmail.com', findRichText: true), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a wrong code stays, the right one opens the app', (tester) async {
    await open(tester);
    await signUp(tester);

    await typeCode(tester, '000000');
    expect(find.text('That code is incorrect.'), findsOneWidget);
    expect(find.text('Page /home'), findsNothing);

    await typeCode(tester, '48291');
    await typeCode(tester, '482917');
    expect(find.text('Page /home'), findsOneWidget);
    expect(server.last['code'], '482917');
    expect(server.last['email'], 'maria.santos@gmail.com');
    expect(server.last['terms_accepted'], true);
    expect(Navigator.of(tester.element(find.text('Page /home'))).canPop(), isFalse);
    await close(tester);
  });

  testWidgets('going back and pressing Sign Up again returns to the code still out', (tester) async {
    await open(tester);
    await signUp(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    server.refuseCode = {'retry_after': 35};
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await settle(tester);
    expect(find.byType(OtpField), findsOneWidget);
    expect(find.textContaining('Resend in 3'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a refused form is said on the form', (tester) async {
    await open(tester);
    server.refuseCode = const {};
    await signUp(tester);
    expect(find.byType(OtpField), findsNothing);
    expect(find.text('This email is already registered.'), findsOneWidget);
    await close(tester);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('the code screen fits ${width.toInt()}px at text scale $scale', (tester) async {
        await RenderHarness.loadFonts(tester);
        RenderHarness.stubPlatformChannels(tester);
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            onGenerateRoute: (_) => MaterialPageRoute(
              settings: const RouteSettings(arguments: {
                'email': 'maria.concepcion.delacruz.santos@gmail.com',
                'signup_password': 'tambayan42rocks!',
                'wait': null,
              }),
              builder: (_) => const VerifyResetCodeScreen(),
            ),
          ),
        ));
        await settle(tester);
        expect(find.text('Resend in 60s'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  }
}

class _Server implements HttpClientAdapter {
  final paths = <String>[];
  Map<String, dynamic> last = {};

  /// Non-null refuses /register/code: empty as taken, else as too soon.
  Map<String, dynamic>? refuseCode;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.path.startsWith('/register')) {
      paths.add(o.path);
      last = Map<String, dynamic>.from(o.data as Map);
    }
    var status = 200;
    Map<String, dynamic> body = {'success': true, 'data': {}, 'message': 'ok'};
    if (o.path == '/register/code' && refuseCode != null) {
      status = refuseCode!.isEmpty ? 422 : 429;
      body = {
        'success': false,
        'data': refuseCode,
        'message': refuseCode!.isEmpty ? 'This email is already registered.' : 'Wait 35 seconds before asking for another code.',
      };
    } else if (o.path == '/register') {
      final right = last['code'] == '482917';
      status = right ? 201 : 422;
      body = right
          ? {
              'success': true,
              'data': {'token': 't', 'user': {'id': 1, 'worker_profile_exists': false}},
              'message': 'ok',
            }
          : {'success': false, 'data': null, 'message': 'That code is incorrect.'};
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
