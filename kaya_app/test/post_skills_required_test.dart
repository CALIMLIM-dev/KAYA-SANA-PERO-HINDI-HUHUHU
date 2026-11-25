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
    Reported: Required Skills was optional. It is what a job is matched to
    workers by, so a post needs at least one.
*/
void main() {
  Map<String, dynamic> job({List<Map<String, dynamic>> skills = const []}) => {
        'id': 7,
        'title': 'Fix the kitchen tap',
        'description': 'Leaking under the sink.',
        'category': {'id': 3, 'name': 'Plumbing'},
        'skills': skills,
        'budget_min': '800.00',
        'budget_period': 'daily',
        'workers_needed': 1,
        'created_at': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().toIso8601String().substring(0, 10),
        'location': 'Urdaneta City',
        'city': 'Urdaneta City, Pangasinan',
        'location_id': 42,
        'latitude': '15.9761',
        'longitude': '120.5711',
        'photo_urls': const ['https://kayaadmin.ucucite.tech/storage/job_photos/a.jpg'],
      };

  Future<void> open(WidgetTester tester, Widget form, {double width = 360, double textScale = 1.0}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 7000);
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
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: form,
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Required Skills'), findsOneWidget, reason: 'The skills never rendered.');
  }

  Future<void> press(WidgetTester tester, String button) async {
    await tester.tap(find.text(button));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  const missing = 'Please add at least one skill.';

  testWidgets('a post with no skill is stopped, and says where', (tester) async {
    await open(tester, PostJobScreen(again: job()));
    expect(find.text(missing), findsNothing, reason: 'Nothing is wrong until Post is pressed.');

    await press(tester, 'Post Job');

    expect(find.text(missing), findsOneWidget);
    // It stopped there: the date was not asked for yet.
    expect(find.text('Please choose the day the post closes.'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a skill typed and not added yet counts', (tester) async {
    await open(tester, PostJobScreen(again: job()));
    await tester.enterText(find.widgetWithText(TextField, 'Add a custom skill...'), 'Faucet Repair');

    await press(tester, 'Post Job');

    expect(find.text(missing), findsNothing);
    expect(find.text('Faucet Repair'), findsWidgets, reason: 'It is on the post now.');
    // On to the next thing missing.
    expect(find.text('Please choose the day the post closes.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a post with a skill goes on as before', (tester) async {
    await open(tester, PostJobScreen(again: job(skills: [{'id': 11, 'name': 'Pipe Repair'}])));

    await press(tester, 'Post Job');

    expect(find.text(missing), findsNothing);
    expect(find.text('Please choose the day the post closes.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an edit is held to it too', (tester) async {
    await open(tester, PostJobScreen(editing: job()));

    await press(tester, 'Save Changes');

    expect(find.text(missing), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('the message fits ${width.toInt()}px at text scale $scale', (tester) async {
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
          await open(tester, PostJobScreen(again: job()), width: width, textScale: scale);
          await press(tester, 'Post Job');
          expect(find.text(missing), findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}
