import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/worker_skill_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/core/constants/employer_type.dart';
import 'package:kaya_app/data/models/employer_profile_model.dart';
import 'package:kaya_app/features/profile/screens/my_employer_profile_screen.dart';
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
    The profile with something in it.

    Every other overflow test in this folder renders screens with empty
    providers, which catches a layout that cannot fit its own furniture and
    nothing else. It cannot catch the reported bug - overflow that appears on
    one account and not another - because the difference between those accounts
    is the content, and an empty screen has none.

    So this one fills the provider first. The values are long in the way real
    ones are: Philippine names carry a middle name and a suffix, addresses run
    barangay-city-province, and a job title is a sentence more often than a
    word.
*/
void main() {
  /// A profile filled the way a real one fills up.
  WorkerProfileProvider populated() {
    final p = WorkerProfileProvider(ApiClient());

    p.name = 'Ricardo Bumanglag Dela Cruz Jr.';
    p.location = 'Barangay Nancayasan, Urdaneta City, Pangasinan';
    p.phone = '+63 912 345 6789';
    p.email = 'ricardo.delacruz.jr@example.com';
    p.latitude = 15.976;
    p.longitude = 120.571;

    /*
        Skills, which the header draws and no test had.

        The header groups them by category and prints the category name in
        capitals above a chip per skill, so a profile with no skills renders a
        header several rows shorter than any real one. That is how it stayed
        eleven pixels over on a real phone while passing here.

        "Appliance Repair" is the longest real category name and the one that
        was on screen when this was reported.
    */
    p.seedSkills([
      WorkerSkillModel(
        id: 1,
        userId: 1,
        skillName: 'Refrigeration and aircon servicing',
        categoryName: 'Appliance Repair',
      ),
      WorkerSkillModel(
        id: 2,
        userId: 1,
        skillName: 'Washing machine repair',
        categoryName: 'Appliance Repair',
      ),
      WorkerSkillModel(
        id: 3,
        userId: 1,
        skillName: 'Panel board wiring',
        categoryName: 'Electrical',
      ),
    ]);

    p.experiences = [
      {
        'id': '1',
        'title': 'Site foreman for two storey residential construction',
        'company': 'Santiago Construction and General Services Incorporated',
        'start_date': '2019-03-01',
        'end_date': '',
        'description': 'Supervised a crew of twelve across three concurrent '
            'residential builds in Urdaneta and San Carlos.',
      },
      {
        'id': '2',
        'title': 'Mason',
        'company': 'Delos Reyes Construction',
        'start_date': '2016-06-01',
        'end_date': '2019-02-01',
        'description': 'Blockwork, plastering and tile setting.',
      },
    ];

    return p;
  }

  /// An employer profile with every field filled, same idea as the worker one.
  EmployerProfileProvider populatedEmployer() {
    final p = EmployerProfileProvider();
    p.seedProfile(EmployerProfile(
      id: 1,
      userId: 1,
      employerType: EmployerType.company,
      companyName: 'Santiago Construction and General Services Incorporated',
      industry: 'Construction and civil works',
      website: 'facebook.com/santiagoconstructionservices',
      description: 'Family run builders working across Pangasinan since 1998, '
          'taking on residential builds, renovations and small commercial fit outs.',
      location: 'Barangay Nancayasan, Urdaneta City, Pangasinan',
      locationId: 1,
      latitude: 15.976,
      longitude: 120.571,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ));
    return p;
  }

  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget screen, {
    required double textScale,
    required double width,
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
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      tester.view.physicalSize = Size(width * 2, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              // The whole point: a provider that already has content, rather
              // than one that will never load any.
              ChangeNotifierProvider<WorkerProfileProvider>.value(
                value: populated(),
              ),
              ChangeNotifierProvider<EmployerProfileProvider>.value(
                value: populatedEmployer(),
              ),
              ChangeNotifierProvider(create: (_) => VerificationProvider()),
              ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
              ChangeNotifierProvider(create: (_) => JobProvider()),
              ChangeNotifierProvider(create: (_) => LocationProvider()),
              ChangeNotifierProvider(create: (_) => CreditsProvider()),
            ],
            child: MaterialApp(home: screen),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Scrolled as well as rested. A list only builds what is on screen, so
      // a row that overflows further down is never laid out by a plain pump
      // and the test would pass without ever having looked at it.
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 120));
      }
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  final screens = <String, Widget>{
    'worker profile': const MyWorkerProfileScreen(),
    'employer profile': const MyEmployerProfileScreen(),
  };

  for (final entry in screens.entries) {
    for (final width in <double>[412, 390, 360, 320]) {
      for (final scale in <double>[1.0, 1.15, 1.3]) {
        testWidgets(
          'a filled ${entry.key} fits ${width.toInt()}px at text scale $scale',
          (tester) async {
            final complaints = await overflowsIn(
              tester,
              entry.value,
              textScale: scale,
              width: width,
            );

            expect(
              complaints,
              isEmpty,
              reason: 'A filled ${entry.key} overflowed at ${width.toInt()}px, '
                  'text scale $scale:\n  ${complaints.join('\n  ')}',
            );
          },
        );
      }
    }
  }
}
