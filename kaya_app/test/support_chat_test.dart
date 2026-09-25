import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/help/screens/support_chat_screen.dart';

import 'support/render_harness.dart';

/*
    Writing to KAYA, and hearing back.

    The empty state matters as much as the thread: somebody opening this has
    a problem and no idea what KAYA wants to know, and a blank box with a
    send button tells them nothing.
*/
void main() {
  List<Map<String, dynamic>> thread() => [
        {
          'id': 1,
          'body': 'My verification was rejected and the message did not say '
              'why. The ID photo was clear and the name matches my profile '
              'exactly, including the middle name.',
          'from_admin': false,
          'from': null,
          'created_at': '2026-09-24T02:00:00Z',
        },
        {
          'id': 2,
          'body': 'Sorry about that. The back of the ID was cut off at the '
              'bottom so the address could not be read. Upload it again with '
              'all four corners in frame and we will approve it the same day.',
          'from_admin': true,
          'from': 'Joed Garin',
          'created_at': '2026-09-24T03:10:00Z',
        },
      ];

  Future<List<String>> render(
    WidgetTester tester, {
    required double width,
    required double textScale,
    List<Map<String, dynamic>>? messages,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        complaints.add(text.split('\n').first.trim());
        return;
      }
      previous?.call(details);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      tester.view.physicalSize = Size(width * 2, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: SupportChatScreen(seed: messages ?? thread()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  testWidgets('a reply is named, so it reads as a person', (tester) async {
    await render(tester, width: 390, textScale: 1.0);

    expect(find.textContaining('the back of the ID was cut off',
        findRichText: true), findsNothing);
    expect(find.textContaining('The back of the ID was cut off'), findsOneWidget);
    expect(find.text('Joed Garin'), findsOneWidget,
        reason: 'an answer from a named person is not the same as one from a platform');
  });

  testWidgets('an empty thread says what to write', (tester) async {
    await render(tester, width: 390, textScale: 1.0, messages: const []);

    expect(find.text('Tell us what happened'), findsOneWidget);
    expect(find.textContaining('which account, job or payment'), findsOneWidget);
    expect(find.text('What can we help with?'), findsOneWidget);
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets(
        'support fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await render(tester, width: width, textScale: scale);

          expect(find.text('Joed Garin'), findsOneWidget,
              reason: 'the thread never rendered, so nothing was checked');

          expect(complaints, isEmpty,
              reason: 'Support overflowed at ${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}');
        },
      );
    }
  }
}
