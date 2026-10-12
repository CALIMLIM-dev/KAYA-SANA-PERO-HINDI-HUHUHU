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
    Reported: the employer's Edit Job was outdated next to Post a Job. Edit
    is the Post a Job form now, filled in from the post - so it has the
    photos, the Duration hint, the trade suggestion and the pin by
    construction, and cannot fall behind again.
*/
void main() {
  final job = <String, dynamic>{
    'id': 7,
    'title': 'Fix the kitchen tap',
    'description': 'Leaking under the sink.',
    'category': {'id': 3, 'name': 'Plumbing'},
    'skills': [
      {'id': 11, 'name': 'Pipe Repair'},
    ],
    'budget_min': '800.00',
    'budget_period': 'daily',
    'is_urgent': false,
    'workers_needed': 2,
    'start_date': '2026-11-02',
    'end_date': '2026-11-03',
    'location': 'Urdaneta City',
    'city': 'Nancayasan, Urdaneta City, Pangasinan',
    'location_id': 42,
    'latitude': '15.9761',
    'longitude': '120.5711',
    'photo_urls': ['https://kayaadmin.ucucite.tech/storage/job_photos/a.jpg'],
  };

  testWidgets('Edit Job opens the Post a Job form filled in from the post', (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
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
      child: MaterialApp(home: PostJobScreen(editing: job)),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Edit Job'), findsOneWidget);
    expect(find.text('Post a Job'), findsNothing);
    expect(find.text('Fix the kitchen tap'), findsOneWidget);
    expect(find.text('Leaking under the sink.'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('Plumbing'), findsWidgets);
    // The post's own photo is shown, with a way to replace it.
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
