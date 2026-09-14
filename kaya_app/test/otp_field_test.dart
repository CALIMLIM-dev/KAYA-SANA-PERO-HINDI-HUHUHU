import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/core/widgets/otp_field.dart';

/*
    The code box.

    The bug these guard against is not a crash: the old profile row drew the
    code entry as a borderless line of text with no visible box, so a screen
    offering "Send code" appeared to have nowhere to type the answer. A test
    that only pumped the widget would have passed on that too, so these
    assert the things that make it read as a field — a box per digit, a real
    TextField behind them, and the digits actually landing in the boxes.
*/
void main() {
  Widget host(TextEditingController c,
      {int length = 6, ValueChanged<String>? onCompleted, bool error = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: OtpField(
            controller: c,
            length: length,
            onCompleted: onCompleted,
            hasError: error,
          ),
        ),
      ),
    );
  }

  testWidgets('draws one box per digit', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    // Containers with a border, sitting inside the field's Row.
    final boxes = tester.widgetList<Container>(find.descendant(
      of: find.byType(OtpField),
      matching: find.byType(Container),
    ));

    expect(boxes.length, 6);
  });

  testWidgets('holds a real text field, not just painted boxes',
      (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    expect(find.descendant(
      of: find.byType(OtpField),
      matching: find.byType(TextField),
    ), findsOneWidget);
  });

  testWidgets('typed digits appear in the boxes', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();

    for (final d in ['1', '2', '3', '4']) {
      expect(find.text(d), findsOneWidget);
    }
    // The two unfilled boxes stay empty rather than showing a placeholder.
    expect(c.text, '1234');
  });

  testWidgets('non-digits are refused', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), '12ab34');
    await tester.pump();

    expect(c.text, '1234');
  });

  testWidgets('stops at the code length', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));

    await tester.enterText(find.byType(TextField), '1234567890');
    await tester.pump();

    expect(c.text, '123456');
  });

  testWidgets('a whole code pasted in one go completes', (tester) async {
    final c = TextEditingController();
    var completed = '';
    await tester.pumpWidget(host(c, onCompleted: (v) => completed = v));

    // Six separate controllers would take only the first digit here, which
    // is why there is one field behind the boxes instead.
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();

    expect(completed, '654321');
  });

  testWidgets('does not fire before the last digit', (tester) async {
    final c = TextEditingController();
    var fired = 0;
    await tester.pumpWidget(host(c, onCompleted: (_) => fired++));

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();

    expect(fired, 0);
  });
}
