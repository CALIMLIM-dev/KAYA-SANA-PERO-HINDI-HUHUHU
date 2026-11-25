import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/post_job_screen.dart';
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
    Job Boost says what it takes before it is touched. An account that had
    never topped up could turn it on, saw the price on the Post button, and
    was told "not enough Barya" after posting.
*/
void main() {
  CreditsProvider credits({required bool toppedUp, int balance = 50, bool loaded = true}) {
    final provider = CreditsProvider()..seedComparison(const [], hasToppedUp: toppedUp)..seedBalance(balance);
    if (loaded) {
      provider.seedCosts({'post_free_days': 7, 'post_days_per_barya': 4, 'boost': 10, 'boost_days': 3});
    }
    return provider;
  }
  Future<void> open(
    WidgetTester tester,
    CreditsProvider wallet, {
    Map<String, dynamic>? editing,
    double width = 360,
    double textScale = 1.0,
  }) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 6000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider<CreditsProvider>.value(value: wallet),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routes: {'/wallet': (_) => const Scaffold(body: Text('The wallet'))},
        home: PostJobScreen(editing: editing),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final boost = find.byKey(const ValueKey('job-boost'));
  Finder inBoost(Finder f) => find.descendant(of: boost, matching: f);

  Future<void> tapBoost(WidgetTester tester) async {
    await tester.tap(boost);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('its price and days are on it before it is touched', (tester) async {
    await open(tester, credits(toppedUp: true));
    expect(inBoost(find.text('10 Barya')), findsOneWidget);
    expect(inBoost(find.text('Top of the job feed for 3 days')), findsOneWidget);
    expect(inBoost(find.byIcon(Icons.lock_outline)), findsNothing);
  });

  testWidgets('topped up: a tap turns it on, with no pop-up, and another off', (tester) async {
    await open(tester, credits(toppedUp: true));

    await tapBoost(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Post for 10 Barya'), findsOneWidget);

    await tapBoost(tester);
    expect(find.text('Post for 10 Barya'), findsNothing);
  });

  testWidgets('never topped up: locked, whatever the balance, and Top Up is right there', (tester) async {
    await open(tester, credits(toppedUp: false, balance: 500));
    expect(inBoost(find.byIcon(Icons.lock_outline)), findsOneWidget, reason: 'Seen before it is touched.');

    await tapBoost(tester);
    expect(find.text('Job Boost needs a top up'), findsOneWidget);
    expect(find.text('Post for 10 Barya'), findsNothing, reason: 'It was not turned on.');
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Top Up'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('The wallet'), findsOneWidget);
  });

  testWidgets('topping up takes the lock off', (tester) async {
    final wallet = credits(toppedUp: false);
    await open(tester, wallet);
    await tapBoost(tester);

    wallet.seedComparison(const [], hasToppedUp: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Job Boost needs a top up'), findsNothing);
    await tapBoost(tester);
    expect(find.text('Post for 10 Barya'), findsOneWidget);
  });

  testWidgets('too little Barya is its own reason', (tester) async {
    await open(tester, credits(toppedUp: true, balance: 4));
    await tapBoost(tester);
    expect(find.text('You have 4 Barya'), findsOneWidget);
    expect(find.text('Post for 10 Barya'), findsNothing);
  });

  testWidgets('with the wallet not loaded nothing is locked on a guess', (tester) async {
    await open(tester, credits(toppedUp: false, loaded: false));
    expect(inBoost(find.byIcon(Icons.lock_outline)), findsNothing);
  });

  testWidgets('a post already boosted is not locked', (tester) async {
    await open(tester, credits(toppedUp: false, balance: 0), editing: {
      'id': 7,
      'title': 'Fix the kitchen tap',
      'description': 'x',
      'category': {'id': 3, 'name': 'Plumbing'},
      'skills': const [],
      'is_urgent': true,
      'budget_min': '800.00',
      'budget_period': 'daily',
      'created_at': DateTime.now().toIso8601String(),
      'end_date': DateTime.now().toIso8601String().substring(0, 10),
      'location': 'Urdaneta City',
      'location_id': 42,
      'photo_urls': const [],
    });
    expect(inBoost(find.text('Paid')), findsOneWidget);
    expect(inBoost(find.byIcon(Icons.lock_outline)), findsNothing);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('Job Boost fits ${width.toInt()}px at text scale $scale', (tester) async {
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
          await open(tester, credits(toppedUp: false), width: width, textScale: scale);
          await tapBoost(tester);
          expect(find.text('Job Boost needs a top up'), findsOneWidget, reason: 'The lock never rendered.');
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}
