import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/community/widgets/community_post_card.dart';
import 'package:kaya_app/features/messaging/widgets/schedule_card.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/schedule_provider.dart';

import 'support/render_harness.dart';

/*
    Reported together on 12 October: a "7 days left" pill on every board
    notice, and a schedule card in the chat that never said the deadline.
*/
void main() {
  testWidgets('a live notice has no countdown, and names its poster', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityPostCard(
          onTap: () {},
          post: const {
            'id': 1,
            'type': 'worker',
            'status': 'live',
            'days_left': 6,
            'title': 'Tile setter, free this week',
            'body': 'Bathrooms and kitchens.',
            'poster': {'id': 9, 'name': 'Ricardo Dela Cruz'},
          },
        ),
      ),
    ));

    expect(find.text('Ricardo Dela Cruz'), findsOneWidget);
    expect(find.textContaining('days left'), findsNothing);
  });

  testWidgets('a schedule card says when the work is due', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ScheduleCard(
            conversationId: 1,
            proposal: {
              'id': 3,
              'proposed_by': 2,
              'status': 'accepted',
              'summary': 'Sat 18 Oct, 8:00 AM',
              'scheduled_date': '2026-10-18',
              'deadline': '2026-10-20',
            },
          ),
        ),
      ),
    ));

    expect(find.text('Sat 18 Oct, 8:00 AM'), findsOneWidget);
    expect(find.text('Done by Tue 20 Oct'), findsOneWidget);
  });
}
