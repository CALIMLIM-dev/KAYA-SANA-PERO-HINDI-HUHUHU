import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/core/widgets/hint_bubble.dart';

/*
    The ? and its bubble.

    What these pin: holding shows the text, it appears beside the icon rather
    than above or below, it takes no layout space, tapping elsewhere closes
    it, and a hint on a button does not steal the button's tap.
*/
void main() {
  Widget host(Widget child, {double width = 400}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Row(children: [
            const SizedBox(width: 40),
            child,
            const Spacer(),
          ]),
        ),
      ),
    );
  }

  testWidgets('holding the ? shows the hint', (tester) async {
    await tester.pumpWidget(host(const HintBubble(text: 'Barya is KAYA credit.')));

    expect(find.text('Barya is KAYA credit.'), findsNothing);

    await tester.longPress(find.byIcon(Icons.help_outline));
    await tester.pump();

    expect(find.text('Barya is KAYA credit.'), findsOneWidget);
  });

  testWidgets('the bubble sits beside the icon, not above or below',
      (tester) async {
    await tester.pumpWidget(host(const HintBubble(text: 'Beside me')));

    await tester.longPress(find.byIcon(Icons.help_outline));
    await tester.pump();

    final icon = tester.getRect(find.byIcon(Icons.help_outline));
    final bubble = tester.getRect(find.text('Beside me'));

    // Same row: the bubble's vertical centre is within the icon's height.
    expect((bubble.center.dy - icon.center.dy).abs(), lessThan(icon.height));
    // And it starts to the right of the icon.
    expect(bubble.left, greaterThan(icon.right));
  });

  testWidgets('with no room on the right it opens on the left',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: const [
          Spacer(),
          HintBubble(text: 'Left side'),
          SizedBox(width: 8),
        ]),
      ),
    ));

    await tester.longPress(find.byIcon(Icons.help_outline));
    await tester.pump();

    final icon = tester.getRect(find.byIcon(Icons.help_outline));
    final bubble = tester.getRect(find.text('Left side'));

    expect(bubble.right, lessThan(icon.left));
  });

  testWidgets('it takes no layout space', (tester) async {
    await tester.pumpWidget(host(const HintBubble(text: 'Floating')));

    final before = tester.getRect(find.byType(Spacer));

    await tester.longPress(find.byIcon(Icons.help_outline));
    await tester.pump();

    // The Spacer beside the icon is exactly where it was - nothing moved.
    expect(tester.getRect(find.byType(Spacer)), before);
  });

  testWidgets('tapping elsewhere closes it', (tester) async {
    await tester.pumpWidget(host(const HintBubble(text: 'Go away')));

    await tester.longPress(find.byIcon(Icons.help_outline));
    await tester.pump();
    expect(find.text('Go away'), findsOneWidget);

    await tester.tapAt(const Offset(300, 500));
    await tester.pump();

    expect(find.text('Go away'), findsNothing);
  });

  testWidgets('holdOnly leaves the tap to the child', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(HintBubble(
      holdOnly: true,
      text: 'What the button does',
      child: TextButton(onPressed: () => taps++, child: const Text('Do it')),
    )));

    await tester.tap(find.text('Do it'));
    await tester.pump();

    expect(taps, 1);
    expect(find.text('What the button does'), findsNothing);

    await tester.longPress(find.text('Do it'));
    await tester.pump();

    expect(find.text('What the button does'), findsOneWidget);
    expect(taps, 1, reason: 'a hold is not a tap');
  });
}
