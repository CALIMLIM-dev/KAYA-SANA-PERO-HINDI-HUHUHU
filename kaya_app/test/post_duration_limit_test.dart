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
    Reported: how long a post can stay up was only said after pressing Post.
    The days themselves show it: the ones an account has, and the rest locked.
*/
void main() {
  CreditsProvider credits({required bool toppedUp, bool loaded = true}) {
    final provider = CreditsProvider()..seedComparison(const [], hasToppedUp: toppedUp);
    if (loaded) provider.seedCosts({'post_free_days': 7, 'post_days_per_barya': 4});
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

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);
  Finder day(int n) {
    final d = inDays(n);
    return find.byKey(ValueKey('open-until-${d.year}-${d.month}-${d.day}'), skipOffstage: false);
  }

  bool locked(int n) => find
      .descendant(of: day(n), matching: find.byIcon(Icons.lock_outline, skipOffstage: false), skipOffstage: false)
      .evaluate()
      .isNotEmpty;

  testWidgets('never topped up: seven days are free and the rest are locked', (tester) async {
    await open(tester, credits(toppedUp: false));

    expect(find.text('Free', skipOffstage: false), findsNWidgets(7));
    expect(locked(6), isFalse);
    expect(locked(7), isTrue);
    expect(find.byIcon(Icons.lock_outline, skipOffstage: false), findsNWidgets(14));
    // Nothing past the row for them, so no calendar to run into it on.
    expect(find.byTooltip('Pick a later day'), findsNothing);
  });

  testWidgets('a free day is picked on a tap, and a locked one never is', (tester) async {
    await open(tester, credits(toppedUp: false));

    await tester.tap(day(2));
    await tester.pump();
    expect(find.text('3 days free'), findsOneWidget);

    await tester.ensureVisible(day(9));
    await tester.pump();
    await tester.tap(day(9));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('The wallet'), findsOneWidget, reason: 'A locked day opens Top Up.');
    expect(find.text('3 days free', skipOffstage: false), findsOneWidget, reason: 'And is not picked.');
  });

  testWidgets('topped up: no locks, and each day says its price', (tester) async {
    await open(tester, credits(toppedUp: true));

    expect(find.byIcon(Icons.lock_outline, skipOffstage: false), findsNothing);
    expect(find.text('Free', skipOffstage: false), findsNWidgets(7));
    expect(find.descendant(of: day(7), matching: find.text('1 Barya', skipOffstage: false), skipOffstage: false), findsOneWidget);
    expect(find.descendant(of: day(11), matching: find.text('2 Barya', skipOffstage: false), skipOffstage: false), findsOneWidget);
    expect(find.byTooltip('Pick a later day'), findsOneWidget);
  });

  testWidgets('with the rule not loaded nothing is guessed', (tester) async {
    await open(tester, credits(toppedUp: false, loaded: false));

    expect(day(0), findsOneWidget);
    expect(find.text('Free', skipOffstage: false), findsNothing);
    expect(find.byIcon(Icons.lock_outline, skipOffstage: false), findsNothing);
  });

  testWidgets('a post already up longer keeps its days', (tester) async {
    String ymd(DateTime d) => d.toIso8601String().substring(0, 10);
    await open(
      tester,
      credits(toppedUp: false),
      editing: {
        'id': 7,
        'title': 'Fix the kitchen tap',
        'description': 'x',
        'category': {'id': 3, 'name': 'Plumbing'},
        'skills': const [],
        'budget_min': '800.00',
        'budget_period': 'daily',
        'workers_needed': 1,
        'created_at': today.toIso8601String(),
        'end_date': ymd(inDays(19)),
        'location': 'Urdaneta City',
        'city': 'Urdaneta City, Pangasinan',
        'location_id': 42,
        'latitude': '15.9761',
        'longitude': '120.5711',
        'photo_urls': const ['https://kayaadmin.ucucite.tech/storage/job_photos/a.jpg'],
      },
    );

    expect(locked(19), isFalse);
    expect(locked(20), isTrue);
  });

  for (final toppedUp in [false, true]) {
    for (final width in <double>[412, 390, 360, 320]) {
      for (final scale in <double>[1.0, 1.15, 1.3]) {
        testWidgets('the limit fits ${width.toInt()}px at text scale $scale, topped up: $toppedUp', (tester) async {
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
            await open(tester, credits(toppedUp: toppedUp), width: width, textScale: scale);
            expect(day(0), findsOneWidget, reason: 'The days never rendered.');
            expect(find.text('Free', skipOffstage: false), findsNWidgets(7));
          } finally {
            FlutterError.onError = previous;
          }
          expect(complaints, isEmpty);
        });
      }
    }
  }
}
