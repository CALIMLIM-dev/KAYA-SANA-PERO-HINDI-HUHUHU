import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/core/widgets/badge_strip.dart';

/*
    Badges, at the sizes that actually break.

    A Wrap only breaks between chips, never inside one, so a single long label
    - "Verified Business" beside "3 Years on KAYA" - is what overflows, and it
    does it on the narrow phone at the large text scale rather than in the
    layout anybody looks at while building. Seven badges is the realistic worst
    case: a verified company with a long record earns nearly the whole set.

    Asserts the strip is on screen before checking it fits. A test that passes
    over a blank area is worse than no test, because it gets believed.
*/
void main() {
  const everything = [
    {'code': 'verified', 'label': 'Verified', 'description': 'Identity confirmed by KAYA'},
    {
      'code': 'verified_business',
      'label': 'Verified Business',
      'description': 'Business documents approved by KAYA'
    },
    {'code': 'jobs_50', 'label': '50 Jobs', 'description': 'Finished 50 jobs'},
    {
      'code': 'highly_rated',
      'label': 'Highly Rated',
      'description': '4.8 average across 23 reviews'
    },
    {'code': 'reliable', 'label': 'Reliable', 'description': '96% of finished jobs completed'},
    {
      'code': 'repeat_hire',
      'label': 'Repeat Hire',
      'description': 'Hired more than once by the same employer'
    },
    {'code': 'veteran', 'label': '3 Years on KAYA', 'description': 'Member since March 2023'},
  ];

  Widget harness(List<Map<String, dynamic>> badges, double width, double scale) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BadgeStrip(badges: badges),
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [412.0, 390.0, 360.0, 320.0]) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets(
        'a full set of badges fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(harness(
            everything.map((b) => Map<String, dynamic>.from(b)).toList(),
            width,
            scale,
          ));
          await tester.pumpAndSettle();

          // On screen before it is checked for fit.
          expect(find.text('Verified Business'), findsOneWidget);
          expect(find.text('3 Years on KAYA'), findsOneWidget);

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('no badges renders nothing rather than an empty box', (tester) async {
    await tester.pumpWidget(harness(const [], 360, 1.0));
    await tester.pumpAndSettle();

    expect(find.byType(Wrap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /*
      An unknown code still renders.

      Badges are added on the server, and a build older than the server must
      show a new one with the neutral icon rather than dropping it or
      throwing.
  */
  testWidgets('a badge code the app does not know still renders', (tester) async {
    await tester.pumpWidget(harness(
      [
        {'code': 'something_new', 'label': 'Top Rated 2026', 'description': 'Awarded by KAYA'}
      ],
      360,
      1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Top Rated 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
