import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/consent_check.dart';
import 'package:kaya_app/features/legal/screens/legal_screen.dart';

void main() {
  testWidgets('the box ticks, and the Terms link opens the Terms instead', (tester) async {
    var agreed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ConsentCheck(
            value: agreed,
            onChanged: (v) => setState(() => agreed = v),
          ),
        ),
      ),
    ));

    expect(find.textContaining('A fake document gets the account banned', findRichText: true), findsOneWidget);

    await tester.tapAt(tester.getTopLeft(find.byType(ConsentCheck)) + const Offset(11, 18));
    await tester.pump();
    expect(agreed, isTrue);

    // The "Terms" words carry a link of their own; following it opens the
    // Terms instead of ticking the box.
    final rich = tester.widget<RichText>(
        // The sentence, not the tick icon, which is drawn as text too.
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Privacy Policy')));
    TapGestureRecognizer? link;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'Terms') link = span.recognizer as TapGestureRecognizer?;
      return true;
    });
    expect(link, isNotNull);
    link!.onTap!();
    await tester.pumpAndSettle();
    final opened = find.byType(LegalScreen).evaluate().isNotEmpty;
    expect(opened, isTrue, reason: 'the Terms link opens the Terms');
  });
}
