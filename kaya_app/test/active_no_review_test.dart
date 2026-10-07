import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    Review lives in History, not in Active.

    Reported from the app: after Mark as complete on the home screen, a
    Review button appeared on the card there. Active is work in progress -
    Message and Mark as complete - and rating somebody belongs with the
    finished jobs. The same finished hire offers Review in History.
*/
void main() {
  Map<String, dynamic> finishedJob() => {
        'id': 41,
        'title': 'Repaint a steel gate',
        'status': 'completed',
        'city': 'Urdaneta City, Pangasinan',
        'budget_min': 900,
        'application_count': 1,
        'hire': {
          'application_id': 77,
          'worker_id': 8,
          'worker_name': 'Mang Tonyo',
          'status': 'completed',
          'employer_completed_at': '2026-10-01T10:00:00Z',
          'worker_completed_at': '2026-10-01T11:00:00Z',
          'i_reviewed_them': false,
          'conversation_id': 12,
        },
        '_isJob': true,
      };

  Future<void> pump(WidgetTester tester, {required bool live}) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: activeCard(finishedJob(), () async {}, live: live),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('History offers Review on a finished hire', (tester) async {
    await pump(tester, live: false);
    expect(find.text('Review Mang Tonyo'), findsOneWidget);
  });

  testWidgets('Active never does', (tester) async {
    await pump(tester, live: true);
    expect(find.text('Repaint a steel gate'), findsOneWidget);
    expect(find.textContaining('Review'), findsNothing);
  });
}
