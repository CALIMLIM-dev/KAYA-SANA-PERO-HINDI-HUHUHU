import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/navigation/main_navigation.dart';
import 'package:kaya_app/core/widgets/top_up_strip.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/screens/profile_screen.dart';
import 'package:kaya_app/features/profile/screens/resume_preview_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';

import 'support/render_harness.dart';

void main() {
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
  });
  tearDown(() => ApiClient.testAdapter = null);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..seedUser({'id': 1, 'name': 'Maria Santos', 'is_verified': false}),
        ),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
      ],
      child: MaterialApp(
        home: child,
        routes: {'/wallet': (_) => const Scaffold(body: Text('The wallet'))},
      ),
    ));
    await settle(tester);
  }

  /*
      Reported: the verified badge appeared only after restarting the app.
  */
  testWidgets('an approval puts the badge on the profile without a restart', (tester) async {
    await show(tester, const ProfileScreen());
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    server.verified = true;
    await tester.runAsync(() => refreshAccount(tester.element(find.byType(ProfileScreen))));
    await settle(tester);

    expect(server.paths, containsAll(['/me', '/verifications']));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  /*
      Reported: What Employers See drew the topped-up resume in full, above a
      Top Up button.
  */
  testWidgets('What Employers See keeps the resume locked until a top up', (tester) async {
    await show(tester, const Scaffold(body: ResumePreviewPopup()));
    expect(find.text('Juan Dela Cruz'), findsOneWidget, reason: 'One card: the one employers see.');
    expect(find.byType(TopUpStrip), findsOneWidget);
    expect(find.text('With Top Up'), findsNothing);
    expect(find.text('NC II Carpentry'), findsNothing, reason: 'Only the open resume lists certificates.');
  });

  testWidgets('topped up, it is the open resume and nothing to buy', (tester) async {
    server.premium = true;
    await show(tester, const Scaffold(body: ResumePreviewPopup()));
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.textContaining('NC II Carpentry'), findsWidgets);
    expect(find.byType(TopUpStrip), findsNothing);
    expect(find.text('Top Up'), findsNothing);
  });
}

class _Server implements HttpClientAdapter {
  bool verified = false;
  bool premium = false;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    paths.add(o.path);
    final data = switch (o.path) {
      '/me' => {'id': 1, 'name': 'Maria Santos', 'is_verified': verified, 'worker_profile_exists': false},
      '/verifications' => [],
      '/worker/profile/resume-preview' => {
          'worker_id': 1,
          'worker_name': 'Juan Dela Cruz',
          'worker_rating': '4.50',
          'worker_rating_count': 3,
          'is_verified': true,
          'verification_state': 'verified',
          'skills': ['Cabinet Making'],
          'category': 'Carpentry',
          'location': 'Urdaneta City, Pangasinan',
          'licenses': [],
          'certifications': ['NC II Carpentry'],
          'experience_label': '3 years',
          'jobs_completed': 4,
          'success_rate': 100,
          'reviews_total': 3,
          'is_new': false,
          'is_premium': premium,
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': data, 'message': 'ok'}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
