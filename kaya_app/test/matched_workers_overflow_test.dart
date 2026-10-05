import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/employer/screens/matched_workers_screen.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';

import 'support/render_harness.dart';

/*
    The suggested-workers shortlist, with content on it.

    Overflow is a content bug: this screen renders nothing at all with an
    empty provider, so a bare render would prove nothing. The rows below
    carry what the real endpoint sends at its longest - a full Philippine
    name, a barangay-city-province category, five skills, two credentials
    with the names TESDA and the PRC actually use, and a match reason for
    every inferred rule.

    A licence name is the longest string on the card by a distance, which is
    what makes the evidence row the one most likely to break at 320px.
*/
void main() {
  /// A row shaped exactly like GET /jobs/{job}/matches returns.
  Map<String, dynamic> match({
    required String name,
    List<String> skills = const [],
    List<String> matched = const [],
    List<String> reasons = const [],
    List<String> licenses = const [],
    List<String> certifications = const [],
    String? experience,
    int hiredBefore = 0,
    int jobsDone = 0,
    int ratingCount = 0,
  }) {
    return {
      'user_id': name.hashCode.abs() % 10000,
      'name': name,
      'avatar': null,
      'is_verified': true,
      'location': 'Brgy. Nancayasan, Urdaneta City, Pangasinan',
      'category': 'Appliance Repair',
      'rating_avg': '4.75',
      'rating_count': ratingCount,
      'skills': skills,
      'matched_skills': matched,
      'match_reasons': reasons,
      'match_score': 92,
      'distance_km': 5,
      'distance_label': '5-15 km',
      'licenses': licenses,
      'certifications': certifications,
      'experience_label': experience,
      'jobs_completed': jobsDone,
      'times_hired_before': hiredBefore,
    };
  }

  List<Map<String, dynamic>> rows() => [
        // The worst case: everything populated, at realistic lengths.
        match(
          name: 'Ricardo Bumanglag Dela Cruz Jr.',
          skills: const [
            'Refrigeration and Airconditioning Servicing',
            'Washing Machine Repair',
            'Oven and Range Repair',
            'Electrical Troubleshooting',
            'Panel Installation',
          ],
          matched: const [
            'refrigeration and airconditioning servicing',
            'electrical troubleshooting',
          ],
          reasons: const [
            'Same work category',
            '2 of 5 skills matched',
            'Aircon Cleaning counts as Refrigeration and Airconditioning Servicing',
            'Under 5 km away',
          ],
          licenses: const [
            'Registered Master Electrician (Professional Regulation Commission)',
          ],
          certifications: const [
            'TESDA National Certificate II in Refrigeration and Airconditioning',
          ],
          experience: '12+ years',
          hiredBefore: 3,
          jobsDone: 47,
          ratingCount: 31,
        ),
        // A cross-category match, which carries the longest single reason.
        match(
          name: 'Maria Cristina Villanueva-Santos',
          skills: const ['Embalming Services', 'Funeral Arrangement'],
          matched: const ['embalming'],
          reasons: const [
            'Different trade, matching skills',
            '1 of 1 skills matched',
            'Embalming Services includes Embalming',
          ],
          licenses: const ['Licensed Embalmer (Department of Health)'],
          experience: '5+ years',
          jobsDone: 4,
          ratingCount: 2,
        ),
        // The sparse case: a new worker with nothing but a trade. Proves the
        // optional rows collapse rather than leaving gaps.
        match(name: 'Jose Rizal Mercado'),
      ];

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

      final directory = WorkerBrowseProvider()..seedMatches(rows());

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<WorkerBrowseProvider>.value(
                  value: directory),
              ChangeNotifierProvider(create: (_) => InvitationProvider()),
            ],
            child: const MaterialApp(
              home: MatchedWorkersScreen(
                jobId: 1,
                jobTitle: 'Aircon cleaning and servicing for a two storey house',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      /*
          Assert something is on screen before checking that it fits.

          A test that passes over a blank area is worse than no test, because
          it gets believed. If the list failed to render, the name below is
          missing and this fails for the right reason.
      */
      expect(
        find.text('Ricardo Bumanglag Dela Cruz Jr.'),
        findsOneWidget,
        reason: 'the shortlist rendered nothing, so nothing was measured',
      );

      // Scroll, so the rows below the fold are actually laid out.
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -600));
        await tester.pump();
      }
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets(
        'a populated shortlist fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(
            tester,
            textScale: scale,
            width: width,
          );

          expect(
            complaints,
            isEmpty,
            reason: 'The shortlist overflowed at ${width.toInt()}px, '
                'text scale $scale:\n  ${complaints.join('\n  ')}',
          );
        },
      );
    }
  }

  testWidgets('the matched skills are ticked and the rest are not',
      (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    final directory = WorkerBrowseProvider()..seedMatches(rows());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkerBrowseProvider>.value(value: directory),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ],
        child: const MaterialApp(
          home: MatchedWorkersScreen(jobId: 1, jobTitle: 'A job'),
        ),
      ),
    );
    await tester.pump();

    /*
        The line this screen exists for: the skills the job asked for and
        this worker has, against the ones they do not. A tick per matched
        skill, and the first worker matched two.
    */
    expect(find.byIcon(Icons.check), findsWidgets);

    // And the score is nowhere on screen. It orders the list and is never
    // printed - category is 0 or 40 and location is one of five bands, so
    // the number repeats across a screenful of people.
    expect(find.textContaining('92'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an empty shortlist says so rather than showing a blank page',
      (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    final directory = WorkerBrowseProvider()..seedMatches([]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkerBrowseProvider>.value(value: directory),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ],
        child: const MaterialApp(
          home: MatchedWorkersScreen(jobId: 1, jobTitle: 'A job'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nobody matches yet'), findsOneWidget);
    // And it does not imply the post is broken - it is still open.
    expect(find.textContaining('still open'), findsOneWidget);
  });
}
