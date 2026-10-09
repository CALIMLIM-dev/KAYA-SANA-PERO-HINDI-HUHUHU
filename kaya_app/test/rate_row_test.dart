import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/profile/widgets/rate_row.dart';

/*
    A job seeker profile states an expected rate, or "to be discussed",
    and matching holds it against the job's budget.
*/
void main() {
  testWidgets('the rate row offers "to be discussed" and hands it back', (tester) async {
    RateChoice? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RateRow(
          label: null,
          rateMin: null,
          rateMax: null,
          rateUnit: null,
          byAgreement: false,
          onSave: (c) async {
            saved = c;
            return null;
          },
        ),
      ),
    ));

    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.text('Expected rate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('To be discussed'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?.byAgreement, isTrue);
  });

  testWidgets('a rate needs a figure, and the top cannot be below the bottom', (tester) async {
    RateChoice? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RateRow(
          label: null, rateMin: null, rateMax: null, rateUnit: null, byAgreement: false,
          onSave: (c) async {
            saved = c;
            return null;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Expected rate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the least you would take, in pesos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '800');
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('The upper figure cannot be below the lower one.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '1200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.min, 800);
    expect(saved?.max, 1200);
    expect(saved?.unit, 'day');
  });
}
