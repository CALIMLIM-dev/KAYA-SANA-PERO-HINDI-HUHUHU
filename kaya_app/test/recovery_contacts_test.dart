import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/core/widgets/otp_field.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/auth/screens/forgot_password_screen.dart';
import 'package:kaya_app/features/auth/screens/verify_reset_code_screen.dart';
import 'package:kaya_app/features/profile/screens/settings_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Email and phone as recovery contacts: shown in Settings (not on the
    profile's ID check), Forgot Password by email or number, a Resend that
    counts down, and a copied code offered for pasting.
*/
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('Settings lists the recovery contacts and whether each is confirmed', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider()
      ..seedUser({
        'id': 1,
        'name': 'Ana Reyes',
        'phone': '09171234567',
        'phone_verified': false,
        'email': 'ana@example.com',
        'email_verified': true,
        'worker_profile_exists': true,
        'employer_profile_exists': false,
      });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();

    expect(find.text('Recovery Contacts'), findsOneWidget);
    expect(find.text('09171234567 · Not confirmed'), findsOneWidget);
    expect(find.text('ana@example.com · Confirmed'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('Forgot Password takes a phone number as well as an email', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MaterialApp(home: ForgotPasswordScreen()),
    ));

    expect(find.text('Email or Phone Number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0917');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();
    expect(find.text('Enter a valid mobile number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ana@');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('Resend waits a minute after the code was sent', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const VerifyResetCodeScreen(),
          settings: const RouteSettings(arguments: {'email': '09171234567'}),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Resend in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Resend in 57s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 58));
    expect(find.text('Resend'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a code copied from the email is offered for pasting', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'Your KAYA code is 482917'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final code = TextEditingController();
    String? completed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OtpField(controller: code, onCompleted: (c) => completed = c)),
    ));
    await tester.pump();

    await tester.tap(find.text('Paste 482917'));
    await tester.pump();

    expect(code.text, '482917');
    expect(completed, '482917');
    expect(find.text('Paste 482917'), findsNothing);
  });
}
