import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/auth/widgets/terms_modal.dart';

/*
    The consent sheet as a person goes through it.

    Testers read the terms to the end, were told to scroll to the bottom of
    both tabs, and stopped: nothing said there was a second page. The sheet
    now walks them there. Checked here: Accept stays off until both pages
    are read, the notice names the page still unread, the Next button
    appears once the terms are read and lands on the privacy policy, and a
    page too short to scroll counts as read on its own.
*/
void main() {
  Future<void> open(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const TermsModal(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder pages() => find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(SingleChildScrollView),
      );

  ElevatedButton acceptButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Accept'));

  testWidgets('walks from the terms to the privacy policy and only then accepts',
      (tester) async {
    await open(tester);

    expect(find.text('1. Terms'), findsOneWidget);
    expect(find.text('2. Privacy'), findsOneWidget);
    expect(find.textContaining('The Privacy Policy comes after it'), findsOneWidget);
    expect(find.text('Next: Privacy Policy'), findsNothing);
    expect(acceptButton(tester).onPressed, isNull);

    // Read the terms to the end.
    await tester.drag(pages().first, const Offset(0, -20000));
    await tester.pumpAndSettle();

    expect(find.text('Next: Privacy Policy'), findsOneWidget);
    expect(find.text('One left: read the Privacy Policy to the end.'), findsOneWidget);
    expect(acceptButton(tester).onPressed, isNull);

    await tester.tap(find.text('Next: Privacy Policy'));
    await tester.pumpAndSettle();

    // On the privacy page now; read it to the end.
    await tester.drag(pages().last, const Offset(0, -20000));
    await tester.pumpAndSettle();

    expect(find.text('Next: Privacy Policy'), findsNothing);
    expect(find.textContaining('One left'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // The checkbox is live now, and Accept follows it.
    expect(acceptButton(tester).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(acceptButton(tester).onPressed, isNotNull);
  });

  testWidgets('a page that needs no scrolling counts as read', (tester) async {
    // Tall enough that both documents fit without scrolling.
    await open(tester, size: const Size(1200, 20000));

    expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));
    expect(find.textContaining('Terms and Conditions to the end'), findsNothing);
  });

  testWidgets('Decline closes the sheet', (tester) async {
    await open(tester);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.byType(TermsModal), findsNothing);
  });
}
