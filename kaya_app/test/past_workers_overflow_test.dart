import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/invitations/screens/past_workers_screen.dart';
import 'package:kaya_app/providers/invitation_provider.dart';

/*
    Worked with before, with content that actually fills the row.

    A long Philippine name, a verified tick, a hire count, a rating and a
    priced button all sit on one line, and the button carries a number that
    grows the widest element on the right. That is the row that breaks at
    320dp and text scale 1.3, and it fits comfortably with the short names a
    developer types while building.

    Asserts a name is on screen before checking the layout, because a test
    that passes over an empty list proves nothing and gets believed anyway.
*/
void main() {
  List<Map<String, dynamic>> workers() => [
        {
          'worker_id': 1,
          'name': 'Maria Cristina Bumanglag-Villanueva',
          'avatar': '',
          'is_verified': true,
          'rating_avg': 4.8,
          'rating_count': 23,
          'times_hired': 3,
          'last_worked_at': '2026-08-01T00:00:00Z',
        },
        {
          'worker_id': 2,
          'name': 'Juan Dela Cruz',
          'avatar': '',
          'is_verified': false,
          'rating_avg': null,
          'rating_count': 0,
          'times_hired': 1,
          'last_worked_at': '2026-07-01T00:00:00Z',
        },
      ];

  Widget screen({required List<Map<String, dynamic>> rows, int? cost}) {
    final invitations = InvitationProvider()..seedPastWorkers(rows, cost: cost);

    return ChangeNotifierProvider<InvitationProvider>.value(
      value: invitations,
      child: const MaterialApp(home: PastWorkersScreen()),
    );
  }

  for (final width in [412.0, 390.0, 360.0, 320.0]) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets(
        'past workers fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: screen(rows: workers(), cost: 1),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // On screen before it is checked for fit.
          expect(find.textContaining('Bumanglag'), findsOneWidget);
          expect(find.textContaining('Hired 3x'), findsOneWidget);

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  /*
      The price is on the button before anything is spent.

      Same rule apply and invite already follow, and the whole point of the
      rehire discount is that the smaller number is visible.
  */
  testWidgets('the reduced price is on the button', (tester) async {
    await tester.pumpWidget(screen(rows: workers(), cost: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Invite'), findsNWidgets(2));
    expect(find.text('1 Barya'), findsNWidgets(2));
  });

  /*
      No price yet means no number, not a guessed one.

      The cost arrives with the list; rendering the standard invite price in
      the meantime would show 2 on a button that charges 1.
  */
  testWidgets('no cost yet shows no price rather than a guessed one', (tester) async {
    await tester.pumpWidget(screen(rows: workers()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Invite'), findsNWidgets(2));
    expect(find.textContaining('Barya'), findsNothing);
  });

  testWidgets('one hire reads as once rather than 1x', (tester) async {
    await tester.pumpWidget(screen(rows: workers(), cost: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Hired once'), findsOneWidget);
  });

  testWidgets('an employer with no finished jobs sees an explanation',
      (tester) async {
    await tester.pumpWidget(screen(rows: const []));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No finished jobs yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
