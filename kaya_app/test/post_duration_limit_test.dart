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

  bool says(int n, String text) => find
      .descendant(of: day(n), matching: find.text(text, skipOffstage: false), skipOffstage: false)
      .evaluate()
      .isNotEmpty;

  testWidgets('one calendar, and no premade one', (tester) async {
    await open(tester, credits(toppedUp: true));
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.byTooltip('Pick a later day'), findsNothing);
    await tester.tap(day(3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    // The price is on the day, not said a second time under it.
    expect(find.textContaining('days free'), findsNothing);
  });

  testWidgets('never topped up: seven days are free and the rest are locked', (tester) async {
    await open(tester, credits(toppedUp: false));

    for (var i = 0; i < 7; i++) {
      expect(says(i, 'Free'), isTrue, reason: 'day $i');
      expect(locked(i), isFalse, reason: 'day $i');
    }
    // On the same page as the free ones, whatever day it is today.
    for (var i = 7; i < 21; i++) {
      expect(locked(i), isTrue, reason: 'day $i');
    }
  });

  testWidgets('a locked day offers the top up inside the calendar, and is not picked', (tester) async {
    await open(tester, credits(toppedUp: false));
    expect(find.text('Top Up'), findsNothing);

    await tester.tap(day(9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('needs a top up'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('The wallet'), findsNothing, reason: 'Nothing opens until Top Up is pressed.');

    // A day they have puts it away.
    await tester.tap(day(2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('needs a top up'), findsNothing);

    await tester.tap(day(9));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Top Up'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('The wallet'), findsOneWidget);
  });

  testWidgets('topping up takes the locks off', (tester) async {
    final wallet = credits(toppedUp: false);
    await open(tester, wallet);
    await tester.tap(day(9));
    await tester.pump(const Duration(milliseconds: 300));

    wallet.seedComparison(const [], hasToppedUp: true);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('needs a top up'), findsNothing);
    expect(locked(9), isFalse);
    expect(says(9, '1 Barya'), isTrue);
  });

  testWidgets('topped up: each day says its price, and later days are further on', (tester) async {
    await open(tester, credits(toppedUp: true));

    expect(find.byIcon(Icons.lock_outline, skipOffstage: false), findsNothing);
    expect(says(6, 'Free'), isTrue);
    expect(says(7, '1 Barya'), isTrue);
    expect(says(11, '2 Barya'), isTrue);

    expect(day(60), findsNothing);
    await tester.tap(find.byTooltip('Later days'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(day(40));
    await tester.pump(const Duration(milliseconds: 300));
    expect(says(40, '9 Barya'), isTrue);
    expect(find.text('Post for 9 Barya'), findsOneWidget, reason: 'It was picked.');
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
            expect(says(6, 'Free'), isTrue);
            await tester.tap(day(9));
            await tester.pump(const Duration(milliseconds: 300));
          } finally {
            FlutterError.onError = previous;
          }
          expect(complaints, isEmpty);
        });
      }
    }
  }
}
