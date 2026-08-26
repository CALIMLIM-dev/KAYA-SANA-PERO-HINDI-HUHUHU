import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/models/worker_profile_model.dart';
import 'package:kaya_app/features/jobs/widgets/jobs_near_you_section.dart';
import 'package:kaya_app/features/jobs/widgets/people_who_can_help_section.dart';

import 'support/render_harness.dart';

/*
    The home carousels, with something in them.

    The screen sweep next door renders whole screens with empty providers,
    which is enough to catch a header that cannot fit its own title and no use
    at all for the bug people actually report. Overflow needs content: a card
    is sized for the text somebody guessed it would hold, and it breaks on the
    job title that runs to two lines or the worker whose town has a long name.

    Both sections are a fixed-height strip wrapping a scrolling row of cards,
    which is the arrangement that fails silently — the strip cannot grow, so
    anything the card needs beyond the number written in the source spills out
    the bottom and paints a striped bar across the busiest screen in the app.

    "Increased from 140 to fix profile overflow" was the comment sitting on one
    of those numbers. It records the fix that does not hold: the next larger
    font finds the new number just as fixed as the old one.
*/
void main() {
  /// Long enough to wrap, which is the whole point.
  Job job(String title) => Job(
        id: title.hashCode,
        title: title,
        company: 'Santiago Construction and General Services',
        location: 'Barangay San Vicente, Urdaneta City, Pangasinan',
        salaryMin: 800,
        salaryMax: 1200,
        salaryPeriod: 'day',
        distance: 3.4,
        category: 'Construction',
        requiredSkills: const ['Masonry', 'Tile setting', 'Plastering'],
        isUrgent: true,
      );

  WorkerProfile worker(String name) => WorkerProfile(
        id: name.hashCode,
        name: name,
        primarySkill: 'Residential electrical installation',
        skills: const ['Wiring', 'Panel boards', 'Troubleshooting'],
        location: 'Barangay Nancayasan, Urdaneta City',
        rating: 4.8,
        reviewCount: 37,
        isVerified: true,
        distance: 2.1,
        yearsOfExperience: 9,
        rateLabel: 'PHP 700 - 900/day',
      );

  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget child, {
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
          // Built from the view, then overridden. A bare MediaQueryData has a
          // zero size, and anything that measures the screen would be sizing
          // itself against a phone 0 pixels wide.
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  final sections = <String, Widget>{
    'jobs near you': JobsNearYouSection(
      jobs: [
        job('Experienced mason needed for a two storey residential build'),
        job('Tile setter'),
      ],
      userLocation: 'Urdaneta City',
    ),
    'people who can help': PeopleWhoCanHelpSection(
      workers: [
        worker('Ricardo Bumanglag Dela Cruz'),
        worker('Ana Reyes'),
      ],
      userLocation: 'Urdaneta City',
      radiusKm: 15,
    ),
  };

  for (final entry in sections.entries) {
    // 360 is the ordinary entry-level Android; 320 is the narrowest still in
    // the wild, and the width the fixed 280px card was never checked against.
    for (final width in <double>[360, 320]) {
      for (final scale in <double>[1.0, 1.15, 1.3]) {
        testWidgets(
          '${entry.key} holds its content at ${width.toInt()}px, text scale $scale',
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
              reason: '${entry.key} overflowed on a ${width.toInt()}px phone at '
                  'text scale $scale:\n  ${complaints.join('\n  ')}',
            );
          },
        );
      }
    }
  }
}
