import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/credits/widgets/plan_comparison.dart';
import 'package:kaya_app/providers/credits_provider.dart';

import 'support/render_harness.dart';

/*
    The Free and Top-up checklist on the wallet screen.

    Two narrow columns of icons beside a column of text that carries prices -
    the exact shape that has overflowed in this app before - so it is swept
    at the small widths and the large text sizes, with the real labels.
*/
void main() {
  const rows = [
    ComparisonRow(label: '20 free barya every month', free: true, toppedUp: true),
    ComparisonRow(
        label: 'Apply to a job (2 barya, about 10 a month on free barya)',
        free: true,
        toppedUp: true),
    ComparisonRow(
        label: 'Keep a job post up past 7 days (1 barya per 4 days)',
        free: false,
        toppedUp: true),
    ComparisonRow(
        label: 'Boost a job or profile to the top (8 barya, 3 days)',
        free: false,
        toppedUp: true),
    ComparisonRow(
        label: 'Your full profile shown to employers when you apply',
        free: false,
        toppedUp: true),
  ];

  Future<List<String>> render(WidgetTester tester,
      {double width = 412, double scale = 1.0, bool toppedUp = false}) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        complaints.add(d.exceptionAsString().split('\n').first);
        return;
      }
      previous?.call(d);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);
      tester.view.physicalSize = Size(width * 2, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: PlanComparison(rows: rows),
            ),
          ),
        ),
      ));
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return complaints;
  }

  testWidgets('a cross for each thing free does not get', (tester) async {
    await render(tester);

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Top-up'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(3));
    expect(find.byIcon(Icons.check), findsNWidgets(7));
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('fits ${width.toInt()}px at scale $scale', (tester) async {
        final complaints = await render(tester, width: width, scale: scale);

        expect(find.text('Boost a job or profile to the top (8 barya, 3 days)'),
            findsOneWidget);
        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
