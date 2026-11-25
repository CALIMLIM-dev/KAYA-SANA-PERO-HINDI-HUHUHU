import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/worker_skill_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/screens/my_worker_profile_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Boost Your Profile says what it takes before it is touched. Somebody who
    had never topped up confirmed a purchase and was refused after it.
*/
void main() {
  CreditsProvider credits({required bool toppedUp, int balance = 50, Map<String, int>? costs}) => CreditsProvider()
    ..seedComparison(const [], hasToppedUp: toppedUp)
    ..seedBalance(balance)
    ..seedCosts(costs ?? {'boost': 10, 'boost_days': 3, 'profile_boost': 6, 'profile_boost_days': 5});

  Future<void> open(WidgetTester tester, CreditsProvider wallet, {double width = 412, double scale = 1.0}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final profile = WorkerProfileProvider(ApiClient())
      ..name = 'Ricardo Bumanglag Dela Cruz Jr.'
      ..location = 'Barangay Nancayasan, Urdaneta City, Pangasinan'
      ..seedSkills([WorkerSkillModel(id: 1, userId: 1, skillName: 'Cabinet Making')]);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<WorkerProfileProvider>.value(value: profile),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider<CreditsProvider>.value(value: wallet),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routes: {'/wallet': (_) => const Scaffold(body: Text('The wallet'))},
        home: const MyWorkerProfileScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Boost Your Profile'), findsOneWidget, reason: 'The card never rendered.');
  }

  testWidgets('its own price and days, not the job boost\'s', (tester) async {
    await open(tester, credits(toppedUp: true));
    expect(find.text('Top of the worker list for 5 days, 6 Barya'), findsOneWidget);
    expect(find.text('Boost'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
  });

  testWidgets('a server that sends one price still shows it', (tester) async {
    await open(tester, credits(toppedUp: true, costs: {'boost': 10, 'boost_days': 3}));
    expect(find.text('Top of the worker list for 3 days, 10 Barya'), findsOneWidget);
  });

  testWidgets('never topped up: locked, whatever the balance, and Top Up opens the wallet', (tester) async {
    await open(tester, credits(toppedUp: false, balance: 500));
    expect(find.text('Needs a top up'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Boost'), findsNothing);

    await tester.tap(find.text('Top Up'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('The wallet'), findsOneWidget);
  });

  testWidgets('too little Barya is its own reason', (tester) async {
    await open(tester, credits(toppedUp: true, balance: 4));
    expect(find.text('You have 4 Barya'), findsOneWidget);
    expect(find.text('Top Up'), findsOneWidget);
  });

  testWidgets('topping up takes the lock off', (tester) async {
    final wallet = credits(toppedUp: false);
    await open(tester, wallet);
    wallet.seedComparison(const [], hasToppedUp: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Needs a top up'), findsNothing);
    expect(find.text('Boost'), findsOneWidget);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('the locked card fits ${width.toInt()}px at text scale $scale', (tester) async {
        final complaints = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            complaints.add(text.split('\n').first.trim());
            return;
          }
          previous?.call(details);
        };
        try {
          await open(tester, credits(toppedUp: false), width: width, scale: scale);
          expect(find.text('Needs a top up'), findsOneWidget);
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}
