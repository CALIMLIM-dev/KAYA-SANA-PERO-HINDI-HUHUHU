import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/worker/widgets/availability_editor.dart';

/*
    The weekly pattern, as a form.

    The rule worth pinning is the one a form gets wrong: ticking the whole day
    after ticking a morning. Both stored renders as "Sat, Sat Morning", so the
    wider answer has to swallow the narrower one - and the other way round,
    because picking a morning after picking the whole day is somebody
    narrowing their answer, not adding to it.
*/
void main() {
  Widget wrap() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AvailabilityEditor()),
        ),
      );

  testWidgets('every day of the week can be set', (tester) async {
    await tester.pumpWidget(wrap());
    // The week draws immediately; the saved pattern arrives later and only
    // if nothing has been ticked in the meantime.
    await tester.pump();

    for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(day), findsOneWidget, reason: '$day is missing');
    }

    // Four ways to answer each day, and no time picker anywhere.
    expect(find.text('Morning'), findsNWidgets(7));
    expect(find.text('Whole day'), findsNWidgets(7));
  });

  testWidgets('the whole day swallows a period already ticked on it',
      (tester) async {
    await tester.pumpWidget(wrap());
    // The week draws immediately; the saved pattern arrives later and only
    // if nothing has been ticked in the meantime.
    await tester.pump();

    // Monday morning, then the whole of Monday.
    await tester.tap(find.text('Morning').first);
    await tester.pump();
    await tester.tap(find.text('Whole day').first);
    await tester.pump();

    final editor = tester.state(find.byType(AvailabilityEditor));

    // ignore: avoid_dynamic_calls
    final pattern = (editor as dynamic).debugPattern as Map<int, Set<String>>;

    expect(pattern[1], {'whole_day'},
        reason: 'Monday kept both the morning and the whole day');
  });

  testWidgets('picking a period narrows a whole day rather than adding to it',
      (tester) async {
    await tester.pumpWidget(wrap());
    // The week draws immediately; the saved pattern arrives later and only
    // if nothing has been ticked in the meantime.
    await tester.pump();

    await tester.tap(find.text('Whole day').first);
    await tester.pump();
    await tester.tap(find.text('Afternoon').first);
    await tester.pump();

    final editor = tester.state(find.byType(AvailabilityEditor));

    // ignore: avoid_dynamic_calls
    final pattern = (editor as dynamic).debugPattern as Map<int, Set<String>>;

    expect(pattern[1], {'afternoon'});
  });

  testWidgets('unticking the last period clears the day entirely',
      (tester) async {
    await tester.pumpWidget(wrap());
    // The week draws immediately; the saved pattern arrives later and only
    // if nothing has been ticked in the meantime.
    await tester.pump();

    await tester.tap(find.text('Morning').first);
    await tester.pump();
    await tester.tap(find.text('Morning').first);
    await tester.pump();

    final editor = tester.state(find.byType(AvailabilityEditor));

    // ignore: avoid_dynamic_calls
    final pattern = (editor as dynamic).debugPattern as Map<int, Set<String>>;

    expect(pattern.containsKey(1), isFalse,
        reason: 'an empty day should not be sent at all');
  });
}
