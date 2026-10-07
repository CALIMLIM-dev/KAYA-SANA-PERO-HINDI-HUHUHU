import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/employer/screens/matched_workers_screen.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';

/*
    The matched list is a Top-up benefit.

    The panel: "a hirer who avails of i-Kaya Points automatically receives
    a list of job seekers whose profiles match". A hirer who has not topped
    up is told how many match and how to see them - never an empty list
    that reads as nobody fitting.
*/
void main() {
  Widget host(WorkerBrowseProvider browse) => MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkerBrowseProvider>.value(value: browse),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ],
        child: const MaterialApp(home: MatchedWorkersScreen(jobId: 7, jobTitle: 'Fix a phone screen')),
      );

  testWidgets('locked: how many, and the way to see them', (tester) async {
    await tester.pumpWidget(host(
      WorkerBrowseProvider()..seedMatches(const [], jobId: 7, locked: true, count: 8),
    ));
    await tester.pump();

    expect(find.text('8 workers match this job'), findsOneWidget);
    expect(find.text('Top up'), findsOneWidget);
    expect(find.text('Nobody matches yet'), findsNothing);
  });

  testWidgets('unlocked: the list itself', (tester) async {
    await tester.pumpWidget(host(
      WorkerBrowseProvider()
        ..seedMatches([
          {'user_id': 5, 'name': 'Eddison Calimlim', 'skills': ['LCD Replacement'], 'matched_skills': ['lcd replacement']},
        ], jobId: 7),
    ));
    await tester.pump();

    expect(find.text('Eddison Calimlim'), findsOneWidget);
    expect(find.text('Top up'), findsNothing);
  });
}
