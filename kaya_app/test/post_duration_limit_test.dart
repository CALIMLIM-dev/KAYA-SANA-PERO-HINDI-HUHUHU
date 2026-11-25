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
    The calendar says it below the days: what the day picked costs, and from
    which one a top up is needed.
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
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String long(int n) => '${months[inDays(n).month - 1]} ${inDays(n).day}, ${inDays(n).year}';

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Open Until *'));
    await tester.pump();
    await tester.tap(find.text('Open Until *'));
    await settle(tester);
    expect(find.byType(CalendarDatePicker), findsOneWidget, reason: 'The calendar never opened.');
  }

  /// Picks a day on the calendar itself, on whichever month it is.
  Future<void> pick(WidgetTester tester, int n) async {
    final day = inDays(n);
    for (var m = (day.year - today.year) * 12 + day.month - today.month; m > 0; m--) {
      await tester.tap(find.byTooltip('Next month'));
      await settle(tester);
    }
    await tester.tap(find.descendant(of: find.byType(CalendarDatePicker), matching: find.text('${day.day}')));
    await settle(tester);
  }

  bool okWorks(WidgetTester tester) => tester.widget<TextButton>(find.widgetWithText(TextButton, 'OK')).onPressed != null;

  testWidgets('one calendar, the one every date uses', (tester) async {
    await open(tester, credits(toppedUp: true));
    expect(find.byType(CalendarDatePicker), findsNothing);
    await openCalendar(tester);
    expect(find.text('Free'), findsOneWidget, reason: 'Said once, below the days.');
    expect(
      tester.getTopLeft(find.text('Free')).dy,
      greaterThan(tester.getBottomLeft(find.byType(CalendarDatePicker)).dy - 1),
    );
  });

  testWidgets('never topped up: the last free day is free and the next is locked', (tester) async {
    await open(tester, credits(toppedUp: false));
    await openCalendar(tester);
    // Before anything is picked.
    final last = inDays(6);
    expect(find.text('Days after ${months[last.month - 1]} ${last.day} need a top up'), findsOneWidget);

    await pick(tester, 6);
    expect(find.text(long(6)), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(okWorks(tester), isTrue);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text(long(6)), findsOneWidget, reason: 'On the form now.');
  });

  testWidgets('a locked day says so below, cannot be chosen, and Top Up is there', (tester) async {
    await open(tester, credits(toppedUp: false));
    await openCalendar(tester);

    await pick(tester, 9);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(okWorks(tester), isFalse);

    await tester.tap(find.text('Top Up'));
    await settle(tester);
    expect(find.text('The wallet'), findsOneWidget);
  });

  testWidgets('topping up takes the lock off while it is open', (tester) async {
    final wallet = credits(toppedUp: false);
    await open(tester, wallet);
    await openCalendar(tester);
    await pick(tester, 9);

    wallet.seedComparison(const [], hasToppedUp: true);
    await settle(tester);
    expect(find.text('Locked'), findsNothing);
    expect(find.textContaining('need a top up'), findsNothing);
    expect(find.text('1 Barya'), findsOneWidget);
    expect(okWorks(tester), isTrue);
  });

  testWidgets('topped up: the price of the day picked, and it reaches the Post button', (tester) async {
    await open(tester, credits(toppedUp: true));
    await openCalendar(tester);
    await pick(tester, 11);
    expect(find.text('2 Barya'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Post for 2 Barya'), findsOneWidget);
  });

  testWidgets('Cancel changes nothing', (tester) async {
    await open(tester, credits(toppedUp: true));
    await openCalendar(tester);
    await pick(tester, 11);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Post for 2 Barya'), findsNothing);
  });

  testWidgets('with the rule not loaded nothing is guessed', (tester) async {
    await open(tester, credits(toppedUp: false, loaded: false));
    await openCalendar(tester);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Locked'), findsNothing);
    expect(find.textContaining('need a top up'), findsNothing);
  });

  testWidgets('a post already up longer keeps its days', (tester) async {
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
        'end_date': inDays(19).toIso8601String().substring(0, 10),
        'location': 'Urdaneta City',
        'city': 'Urdaneta City, Pangasinan',
        'location_id': 42,
        'latitude': '15.9761',
        'longitude': '120.5711',
        'photo_urls': const ['https://kayaadmin.ucucite.tech/storage/job_photos/a.jpg'],
      },
    );
    await openCalendar(tester);
    final last = inDays(19);
    expect(find.text('Days after ${months[last.month - 1]} ${last.day} need a top up'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
    expect(okWorks(tester), isTrue);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('the calendar fits ${width.toInt()}px at text scale $scale', (tester) async {
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
          await openCalendar(tester);
          expect(find.textContaining('need a top up'), findsOneWidget, reason: 'The lock never rendered.');
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}
