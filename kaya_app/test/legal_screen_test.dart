import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/legal/data/legal_documents.dart';
import 'package:kaya_app/features/legal/screens/legal_screen.dart';

/// Reading the policies must not behave like agreeing to them.
void main() {
  Future<void> pump(WidgetTester tester, {int tab = 0}) async {
    await tester.pumpWidget(MaterialApp(home: LegalScreen(initialTab: tab)));
    await tester.pumpAndSettle();
  }

  testWidgets('opens as a list of titles, not a wall of text', (tester) async {
    await pump(tester);
    final sections = LegalDocuments.terms.sections;

    // Several headings are on screen at once — collapsed, the document reads
    // as its own contents page.
    for (final section in sections.take(5)) {
      expect(find.text(section.title), findsOneWidget);
    }

    // No body text until something is tapped.
    for (final section in sections.take(5)) {
      expect(find.text(section.body), findsNothing);
    }

    // The list is lazy, so the last heading needs a scroll — but it is a short
    // one, because only headings occupy the space. Dragging the list itself
    // rather than scrollUntilVisible, which cannot tell the ListView apart from
    // the TabBarView's own scrollable.
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text(sections.last.title), findsOneWidget);
  });

  testWidgets('tapping a section reveals only that section', (tester) async {
    await pump(tester);
    final sections = LegalDocuments.terms.sections;

    await tester.tap(find.text(sections[2].title));
    await tester.pumpAndSettle();

    expect(find.text(sections[2].body), findsOneWidget);
    expect(find.text(sections[0].body), findsNothing);
  });

  testWidgets('expand all opens everything, then collapses it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Expand all'));
    await tester.pumpAndSettle();
    expect(find.text('Collapse all'), findsOneWidget);
    // First body is on screen without scrolling.
    expect(find.text(LegalDocuments.terms.sections.first.body), findsOneWidget);

    await tester.tap(find.text('Collapse all'));
    await tester.pumpAndSettle();
    expect(find.text(LegalDocuments.terms.sections.first.body), findsNothing);
  });

  testWidgets('carries no consent controls at all', (tester) async {
    await pump(tester);

    // The whole point of splitting this from the sign-up sheet.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(find.textContaining('Scroll to continue'), findsNothing);
    expect(find.textContaining('scroll to the bottom'), findsNothing);
  });

  testWidgets('can open straight onto the privacy policy', (tester) async {
    await pump(tester, tab: 1);

    expect(find.text(LegalDocuments.privacy.sections.first.title), findsOneWidget);
  });

  testWidgets('an opened section survives switching tabs', (tester) async {
    await pump(tester);
    final first = LegalDocuments.terms.sections.first;

    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(find.text(first.body), findsOneWidget);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();

    expect(find.text(first.body), findsOneWidget, reason: 'should not silently collapse');
  });

  test('both documents are non-empty and every section has a body', () {
    for (final doc in [LegalDocuments.terms, LegalDocuments.privacy]) {
      expect(doc.sections, isNotEmpty);
      for (final s in doc.sections) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.body.trim().length, greaterThan(40));
        // Numbers are rendered from the index, so baking them into the title
        // would show up as "1. 1. Who Can Use KAYA".
        expect(RegExp(r'^\d+\.').hasMatch(s.title), isFalse,
            reason: 'title should not carry its own number: ${s.title}');
      }
    }
  });
}
