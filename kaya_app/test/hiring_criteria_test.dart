import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/applications/widgets/fit_facts.dart';
import 'package:kaya_app/features/profile/widgets/work_preference_rows.dart';

/*
    The job seeker profile feeds matching: each hiring criterion comes back
    as a fact the hirer can read, met or not.
*/
void main() {
  testWidgets('each criterion is one line, marked met, missed or not judged', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CriteriaFacts(row: {
          'criteria': [
            {'key': 'rate', 'met': true, 'text': 'Asks ₱600/day, within budget'},
            {'key': 'days', 'met': false, 'text': 'Does not work Sat'},
            {'key': 'rate', 'met': null, 'text': 'Rate to be discussed'},
          ],
        }),
      ),
    ));

    expect(find.text('Asks ₱600/day, within budget'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });

  test('a row without criteria shows nothing', () {
    expect(CriteriaFacts.hasAny(const {}), isFalse);
  });

  test('the days read as people say them', () {
    expect(daysLabel([1, 2, 3, 4, 5, 6, 7]), 'Every day');
    expect(daysLabel([5, 1, 2, 3, 4]), 'Mon-Fri');
    expect(daysLabel([1, 3, 6]), 'Mon, Wed, Sat');
    expect(daysLabel(const []), '');
  });

  testWidgets('choosing days saves them in order', (tester) async {
    List<int>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkDaysRow(days: const [], onSave: (d) async {
          saved = d;
          return null;
        }),
      ),
    ));

    await tester.tap(find.text('Days you can work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sat'));
    await tester.tap(find.text('Mon'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, [1, 6]);
  });
}
