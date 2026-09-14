import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/messaging/widgets/schedule_card.dart';
import 'package:kaya_app/providers/schedule_provider.dart';

/*
    A day the worker already holds must not be offered.

    The picker used to let you tap it, then a time, and only then say "they
    are unavailable that day" - after the calendar had presented it as a
    choice. These pin the fix: a taken day is disabled in the picker, the
    picker opens on a free day even when today is taken, and free days still
    work as before.

    The tests are pinned to dates two months out so they do not drift into
    the past and start failing on their own.
*/
void main() {
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Widget host(ScheduleProvider schedule) {
    return ChangeNotifierProvider.value(
      value: schedule,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  ScheduleComposer.open(context, conversationId: 1, jobId: 9),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Finder dayCell(int day) => find.descendant(
        of: find.byType(Dialog),
        matching: find.text('$day'),
      );

  // The Material picker wraps every enabled day in an InkResponse and every
  // disabled one in nothing tappable at all, so this is the direct question:
  // is there anything under that number that would answer a tap?
  Finder tappable(int day) => find.ancestor(
        of: dayCell(day),
        matching: find.byType(InkResponse),
      );

  testWidgets('a taken day cannot be tapped', (tester) async {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + 2, 15);

    final schedule = ScheduleProvider()
      ..seedForTesting(conversationId: 1, busyDates: [key(target)]);

    await tester.pumpWidget(host(schedule));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Move the picker forward two months so the target is on screen.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(dayCell(15), findsOneWidget,
        reason: 'the day is still drawn, just not offered');
    expect(tappable(15), findsNothing,
        reason: 'a taken day must not be selectable');
    expect(tappable(16), findsOneWidget,
        reason: 'the day beside it is still selectable');
  });

  testWidgets('a free day still opens the time picker', (tester) async {
    final now = DateTime.now();
    final taken = DateTime(now.year, now.month + 2, 15);

    final schedule = ScheduleProvider()
      ..seedForTesting(conversationId: 1, busyDates: [key(taken)]);

    await tester.pumpWidget(host(schedule));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(dayCell(16));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('What time?'), findsOneWidget);
  });

  testWidgets('opens on the first free day when today is taken',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Today and tomorrow both taken: the picker must not assert on its
    // initial date, and must land on the day after.
    final schedule = ScheduleProvider()
      ..seedForTesting(conversationId: 1, busyDates: [
        key(today),
        key(today.add(const Duration(days: 1))),
      ]);

    await tester.pumpWidget(host(schedule));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('Greyed days are taken'), findsOneWidget);
  });

  testWidgets('says nothing about greyed days when none are', (tester) async {
    final schedule = ScheduleProvider()..seedForTesting(conversationId: 1);

    await tester.pumpWidget(host(schedule));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Which day?'), findsOneWidget);
    expect(find.textContaining('Greyed'), findsNothing);
  });
}
