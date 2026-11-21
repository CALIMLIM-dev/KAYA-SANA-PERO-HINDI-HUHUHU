import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/help/screens/faq_screen.dart';
import 'package:kaya_app/features/legal/data/legal_documents.dart';
import 'package:kaya_app/features/legal/screens/legal_screen.dart';

/*
    The FAQ can be searched, and the Refund Policy is its own document with
    its own tab.
*/
void main() {
  testWidgets('searching the FAQ narrows it and opens the answers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FAQScreen()));

    expect(find.text('How do I create an account?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'top up');
    await tester.pumpAndSettle();

    expect(find.text('How do I create an account?'), findsNothing);
    expect(find.text('How do I top up?'), findsOneWidget);
    // Opened without a tap.
    expect(find.textContaining('Scan the GCash QR'), findsOneWidget);
  });

  testWidgets('a search with no match says what to do', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FAQScreen()));

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing matches that'), findsOneWidget);
  });

  testWidgets('the refund policy opens the Terms on its Refunds section, already open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen(openSection: LegalDocuments.refundsSection)));
    await tester.pumpAndSettle();

    // Two documents now: the refund rules are part of the Terms.
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    final refunds = LegalDocuments.terms.sections.firstWhere((s) => s.title == LegalDocuments.refundsSection);
    expect(find.text(refunds.body), findsOneWidget, reason: 'the Refunds section is open and on screen');
  });

  test('the policies name no AI model or provider, and keep what the law asks for', () {
    final all = [LegalDocuments.terms, LegalDocuments.privacy].expand((d) => d.sections).map((s) => '${s.title} ${s.body}').join(' ');

    for (final name in ['Gemini', 'Claude', 'Anthropic', 'Jina', 'Voyage', 'OmniRoute', 'Semaphore']) {
      expect(all.contains(name), isFalse, reason: name);
    }
    expect(all.contains('Data Protection Officer'), isTrue);
    expect(all.contains('72 hours'), isTrue);
    expect(all.contains('outside the Philippines'), isTrue);
    expect(all.contains('last ten messages'), isTrue);
    expect(all.contains('appeal'), isTrue);
  });

  test('no document still promises the refund the app stopped giving', () {
    final all = [LegalDocuments.terms, LegalDocuments.privacy]
        .expand((d) => d.sections)
        .map((s) => s.body)
        .join(' ');

    // A hire no longer cancels the worker's clashing applications.
    expect(all.contains('clashed'), isFalse);
    // There is no push token, and admins do not read reported chats.
    expect(all.contains('token that lets us show you notifications'), isFalse);
    expect(all.contains('read the recent messages'), isFalse);
  });
}
