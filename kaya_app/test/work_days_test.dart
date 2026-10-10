import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/profile/widgets/work_preference_rows.dart';

/*
    The days a worker works, set on their profile and read by matching.
*/
void main() {
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
