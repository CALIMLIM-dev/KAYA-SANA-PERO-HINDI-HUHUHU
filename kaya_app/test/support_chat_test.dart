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
    Map<String, dynamic>? assistant,
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
            home: SupportChatScreen(seed: messages ?? thread(), seedAssistant: assistant),
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

    expect(find.text('Tell Us What Happened'), findsOneWidget);
    expect(find.textContaining('which account, job or payment'), findsOneWidget);
    expect(find.text('What can we help with?'), findsOneWidget);
  });

  const menu = [
    {'key': 'topic:account', 'label': 'Account or Suspension'},
    {'key': 'topic:barya', 'label': 'Barya and Top-up'},
    {'key': 'topic:bug', 'label': "Something's Broken"},
  ];

  testWidgets('an empty chat opens on the greeting and its menu', (tester) async {
    await render(tester, width: 390, textScale: 1.0, messages: const [], assistant: {
      'on': true, 'with_person': false, 'greeting': 'Hi, I am KAYA Assistant.', 'menu': menu,
    });

    expect(find.text('Hi, I am KAYA Assistant.'), findsOneWidget);
    expect(find.text('Barya and Top-up'), findsOneWidget);
    expect(find.text("Something's Broken"), findsOneWidget);
    expect(find.text('This chat clears when you leave it.'), findsOneWidget);
    expect(find.text('KAYA Assistant'), findsWidgets);
  });

  testWidgets('an answer shows its fix buttons and the next choices', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {'on': true, 'with_person': false, 'menu': menu}, messages: [
      ...thread(),
      {
        'id': 3,
        'body': 'Your balance is 50 Barya.\n\nTop-ups are added at once.',
        'from_admin': true,
        'from_assistant': true,
        'from': 'KAYA Assistant',
        'payload': {
          'actions': [{'key': 'wallet', 'label': 'Open My Wallet', 'route': '/wallet'}],
          'options': [
            {'key': 'helped', 'label': 'Yes, Solved'},
            {'key': 'agent', 'label': 'Talk to an Agent'},
          ],
        },
        'created_at': '2026-09-24T03:11:00Z',
      },
    ]);

    expect(find.text('Open My Wallet'), findsOneWidget);
    expect(find.text('Yes, Solved'), findsOneWidget);
    expect(find.text('Talk to an Agent'), findsOneWidget);
    // A small button to report the answer, on assistant answers only.
    expect(find.byTooltip('Report This Answer'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  testWidgets('in line, the header shows the place and the wait', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {
      'on': true, 'with_person': true, 'team_online': true, 'line': {'position': 2, 'eta_minutes': 6},
    });

    expect(find.text('#2 in line · about 6 min'), findsOneWidget);
    expect(find.text('Back to Assistant'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsNothing);
  });

  testWidgets('with the team offline, the person is told', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {
      'on': true, 'with_person': true, 'team_online': false, 'line': {'position': 1},
    });

    expect(find.textContaining('The team is offline'), findsOneWidget);
  });

  testWidgets('an agent joined: named in the header, and a divider in the chat', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {'on': true, 'with_person': true, 'agent': 'Ana'}, messages: [
      ...thread(),
      {'id': 3, 'body': 'Ana from KAYA joined the chat.', 'from_admin': true, 'kind': 'event', 'created_at': '2026-09-24T03:12:00Z'},
    ]);

    expect(find.text('Ana from KAYA'), findsOneWidget);
    expect(find.text('Ana from KAYA joined the chat.'), findsOneWidget);
    expect(find.text('Back to Assistant'), findsNothing);
  });

  testWidgets('with the assistant off, there is no menu', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {'on': false, 'with_person': false});

    expect(find.byTooltip('Menu'), findsNothing);
    expect(find.text('Back to Assistant'), findsNothing);
  });

  testWidgets('your own message sits on the right, KAYA on the left', (tester) async {
    await render(tester, width: 390, textScale: 1.0);

    final mine = tester.getRect(find.textContaining('My verification was rejected'));
    final theirs = tester.getRect(find.textContaining('The back of the ID was cut off'));
    expect(mine.right, greaterThan(390 - 40), reason: 'the person\'s bubble hugs the right edge');
    expect(mine.left, greaterThan(theirs.left + 40), reason: 'and is not stacked under the reply');
    expect(theirs.left, lessThan(40));
  });

  testWidgets('Menu is off while the menu is already the newest line', (tester) async {
    await render(tester, width: 390, textScale: 1.0, assistant: {'on': true, 'with_person': false, 'menu': menu}, messages: [
      ...thread(),
      {
        'id': 3, 'body': 'What do you need help with?', 'from_admin': true, 'from_assistant': true,
        'from': 'KAYA Assistant', 'payload': {'options': menu},
      },
    ]);

    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.apps_rounded));
    expect(button.onPressed, isNull, reason: 'pressing it again only repeated the menu');
    expect(find.text('Barya and Top-up'), findsOneWidget);
  });

  testWidgets("Something's Broken opens a pop-up that fits a small phone", (tester) async {
    await render(tester, width: 320, textScale: 1.3, messages: const [], assistant: {
      'on': true, 'with_person': false, 'greeting': 'Hi.', 'menu': menu,
    });

    await tester.tap(find.text("Something's Broken"));
    await tester.pumpAndSettle();

    expect(find.text('What Happened?'), findsOneWidget);
    expect(find.text('A button does nothing'), findsOneWidget);
    expect(find.text('Send Report'), findsOneWidget);

    await tester.tap(find.text('The app closed by itself'));
    await tester.pump();
    final picked = tester.widget<Icon>(find.descendant(
      of: find.ancestor(of: find.text('The app closed by itself'), matching: find.byType(Row)).first,
      matching: find.byType(Icon),
    ));
    expect(picked.icon, Icons.radio_button_checked);
  });

  testWidgets('a known issue the team posted is pinned when the chat opens', (tester) async {
    await render(tester, width: 360, textScale: 1.3, messages: const [], assistant: {
      'on': true, 'with_person': false, 'greeting': 'Hi.', 'menu': menu,
      'notices': [
        {'text': 'Top-ups are slow today. They will show by 3 PM.', 'topic': 'Barya and Top-up'},
      ],
    });

    expect(find.textContaining('Known Issue (Barya and Top-up): ', findRichText: true), findsOneWidget);
    expect(find.textContaining('Top-ups are slow today', findRichText: true), findsOneWidget);
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets(
        'support fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await render(tester, width: width, textScale: scale,
              assistant: {'on': true, 'with_person': false, 'menu': menu});

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
