import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/models/category_model.dart';
import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/models/worker_profile_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/search_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    The rebuilt search: the worker side with real-length content, the filter
    sheet on both sides, and recent searches coming back.

    Rendered with providers seeded, at the widths and text scales CLAUDE.md
    asks for, and checked for content on screen before checking it fits.
*/
void main() {
  WorkerProfile worker(String name) => WorkerProfile(
        id: name.hashCode,
        userId: name.hashCode,
        name: name,
        primarySkill: 'Mason and tile setter',
        location: 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        rating: 4.8,
        reviewCount: 12,
        completedJobs: 34,
        isVerified: true,
        distance: 3.4,
      );

  Job job(String title) => Job(
        id: title.hashCode,
        title: title,
        company: 'Santiago Construction and General Services Incorporated',
        location: 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        salaryMin: 800,
        salaryMax: 1200,
        salaryPeriod: 'day',
        distance: 3.4,
        category: 'Construction',
        requiredSkills: const ['Masonry', 'Tile setting'],
      );

  List<CategoryModel> categories() => const [
        'Aircon Cleaning and Repair', 'Carpentry', 'Electrical', 'Masonry', 'Plumbing',
      ].asMap().entries.map((e) => CategoryModel(id: e.key + 1, name: e.value)).toList();

  Widget app({required bool employer, required double textScale, required WidgetTester tester}) {
    return MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(textScale)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())..seedCategories(categories())),
          ChangeNotifierProvider(create: (_) => JobProvider()..seedPublicJobs([job('Tile setter for a bathroom')])),
          ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
          ChangeNotifierProvider<AppModeProvider>.value(
            value: AppModeProvider()..reconcile(hasWorker: !employer, hasEmployer: employer),
          ),
          ChangeNotifierProvider(create: (_) => ApplicationProvider()),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
          ChangeNotifierProvider(create: (_) => MessagingProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(
            create: (_) => WorkerBrowseProvider()
              ..seedWorkers(directory: [
                worker('Antonio Mangubat Dela Cruz Jr.'),
                worker('Merly Villanueva-Santiago'),
              ]),
          ),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
  }

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required bool employer,
    required double width,
    required double textScale,
    bool openFilters = false,
  }) async {
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
      SharedPreferences.setMockInitialValues({});
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);
      tester.view.physicalSize = Size(width * 2, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(employer: employer, textScale: textScale, tester: tester));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(employer ? 'Antonio Mangubat Dela Cruz Jr.' : 'Tile setter for a bathroom'),
        findsOneWidget,
        reason: 'The results never rendered, so nothing was checked.',
      );
      expect(find.text('Plumbing'), findsOneWidget, reason: 'The trade row never rendered.');

      if (openFilters) {
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Where'), findsOneWidget);
        // The sheet's last control, scrolled to, so it is laid out too.
        await tester.dragUntilVisible(
          find.text(employer ? 'Verified workers only' : 'Urgent jobs only'),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        expect(find.text(employer ? 'Verified workers only' : 'Verified employers only'), findsOneWidget);
        expect(find.text('Show results'), findsOneWidget);
      }
    } finally {
      FlutterError.onError = previous;
    }
    return complaints;
  }

  for (final employer in [false, true]) {
    final side = employer ? 'workers' : 'jobs';
    for (final width in [412.0, 390.0, 360.0, 320.0]) {
      for (final scale in [1.0, 1.15, 1.3]) {
        testWidgets('search for $side fits ${width.toInt()}px at text scale $scale', (tester) async {
          expect(await overflowsIn(tester, employer: employer, width: width, textScale: scale), isEmpty);
        });
      }
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('the $side filter sheet fits 320px at text scale $scale', (tester) async {
        expect(
          await overflowsIn(tester, employer: employer, width: 320, textScale: scale, openFilters: true),
          isEmpty,
        );
      });
    }
  }

  testWidgets('recent searches come back, and can be cleared', (tester) async {
    SharedPreferences.setMockInitialValues({
      'search_recent_jobs': ['mason', 'tile setter'],
    });
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(employer: false, textScale: 1.0, tester: tester));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('mason'), findsOneWidget);
    expect(find.text('tile setter'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('mason'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_recent_jobs'), isEmpty);
  });
}
