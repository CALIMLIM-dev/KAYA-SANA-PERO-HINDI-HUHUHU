import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/constants/credits.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/auth/screens/reset_password_screen.dart';
import 'package:kaya_app/features/auth/screens/welcome_screen.dart';
import 'package:kaya_app/features/credits/screens/wallet_history_screen.dart';
import 'package:kaya_app/features/reviews/screens/leave_review_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/review_provider.dart';

import 'support/render_harness.dart';

/*
    Screens the November audit found no test for, driven the way a person
    uses them: what has to be filled in before the button works, and what
    goes to the server when it does.
*/
void main() {
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
  });
  tearDown(() => ApiClient.testAdapter = null);

  /// Pushes [screen] with [args] over a plain home, at a 360-wide phone.
  Future<void> open(WidgetTester tester, Widget screen,
      {Object? args, List<ChangeNotifierProvider> providers = const [], bool signedIn = true}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' && signedIn ? 'token' : null,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final app = MaterialApp(
      routes: {'/login': (_) => const Scaffold(body: Text('Sign In Page'))},
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                settings: RouteSettings(arguments: args),
                builder: (_) => screen,
              )),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(providers.isEmpty ? app : MultiProvider(providers: providers, child: app));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
  }

  group('Write a Review', () {
    final args = {'revieweeName': 'Maria Santos', 'revieweeRole': 'worker', 'revieweeId': 9, 'jobId': 3, 'jobTitle': 'Fix the gate'};

    testWidgets('needs a rating and ten letters, then sends both', (tester) async {
      await open(tester, const LeaveReviewScreen(), args: args, providers: [
        ChangeNotifierProvider<ReviewProvider>(create: (_) => ReviewProvider()),
      ]);

      final submit = find.widgetWithText(ElevatedButton, 'Submit Review');
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull, reason: 'nothing chosen yet');

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Short');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull, reason: 'under ten letters');

      await tester.enterText(find.byType(TextField).last, 'Maayos at mabilis gumawa.');
      await tester.pump();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(server.posted['/reviews'], isNotNull);
      expect(server.posted['/reviews']!['rating'], 4);
      expect(server.posted['/reviews']!['reviewee_id'], 9);
      expect(server.posted['/reviews']!['job_id'], 3);
      expect(find.byType(LeaveReviewScreen), findsNothing, reason: 'closes once sent');
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Reset Password', () {
    final args = {'email': 'ana@example.com', 'code': '123456'};

    testWidgets('passwords that do not match are not sent', (tester) async {
      await open(tester, const ResetPasswordScreen(), args: args, providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ]);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Kaya-Safe-2026');
      await tester.enterText(fields.at(1), 'Kaya-Safe-2027');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(server.posted.containsKey('/reset-password'), isFalse);
    });

    testWidgets('a matching pair is sent with the code and goes to sign in', (tester) async {
      await open(tester, const ResetPasswordScreen(), args: args, providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ]);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Kaya-Safe-2026');
      await tester.enterText(fields.at(1), 'Kaya-Safe-2026');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));

      expect(server.posted['/reset-password']!['email'], 'ana@example.com');
      expect(server.posted['/reset-password']!['code'], '123456');
      expect(find.text('Sign In Page'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Wallet History', () {
    testWidgets('lists the account\'s own rows, in words', (tester) async {
      await open(tester, const WalletHistoryScreen(), providers: [
        ChangeNotifierProvider<CreditsProvider>(create: (_) => CreditsProvider()..loadHistory()),
      ]);

      expect(server.asked, contains('/credits/transactions'));
      expect(find.text(Credits.describe('topup', isRefund: false)), findsWidgets);
    });
  });

  group('Welcome', () {
    testWidgets('signed out on a first open, it shows the introduction and fits', (tester) async {
      await open(tester, const WelcomeScreen(), signedIn: false, providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ]);

      expect(find.text('Find Workers Near You'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _Server implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> posted = {};
  final List<String> asked = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    asked.add(o.path);
    if (o.method == 'POST') {
      posted[o.path] = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : {};
      return _json({'success': true, 'data': {}, 'message': 'Done'}, o.path == '/reviews' ? 201 : 200);
    }
    if (o.path == '/credits/transactions') {
      return _json({
        'success': true,
        'data': {
          'data': [
            {'id': 1, 'delta': 60, 'balance_after': 60, 'reason': 'topup', 'is_refund': false, 'created_at': '2026-11-13T08:00:00Z'},
          ],
        },
      });
    }
    return _json({'success': true, 'data': []});
  }

  ResponseBody _json(Map<String, dynamic> body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}
