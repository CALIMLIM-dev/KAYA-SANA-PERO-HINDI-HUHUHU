import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
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
              ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
              ChangeNotifierProvider(create: (_) => VerificationProvider()),
              ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
              ChangeNotifierProvider(create: (_) => JobProvider()),
              ChangeNotifierProvider(create: (_) => LocationProvider()),
              ChangeNotifierProvider(create: (_) => CreditsProvider()),
            ],
            child: const MaterialApp(home: MyWorkerProfileScreen()),
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

  for (final width in <double>[360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets(
        'a filled worker profile fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(
            tester,
            textScale: scale,
            width: width,
          );

          expect(
            complaints,
            isEmpty,
            reason: 'A filled profile overflowed at ${width.toInt()}px, '
                'text scale $scale:\n  ${complaints.join('\n  ')}',
          );
        },
      );
    }
  }
}
