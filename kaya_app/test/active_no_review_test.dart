import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    Mark as complete, then Review, on the same card on home.

    Completion happens on the home screen's Active cards, so the Review that
    follows belongs there too - for the employer and the worker alike. The
    finished job stays in Active until it is reviewed or the review window
    closes, and never past that: a Review button left for months, refused
    every time it was pressed, was the bug on the other side.
*/
void main() {
  String inDays(int d) => DateTime.now().add(Duration(days: d)).toIso8601String();

  Map<String, dynamic> finishedJob({String? closes, bool reviewed = false}) => {
        'id': 41,
        'title': 'Repaint a steel gate',
        'status': 'completed',
        'is_live': false,
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
          'i_reviewed_them': reviewed,
          'review_closes_at': closes,
          'conversation_id': 12,
        },
      };

  Map<String, dynamic> finishedWork({String? closes}) => {
        'id': 77,
        'status': 'completed',
        'worker_completed_at': '2026-10-01T11:00:00Z',
        'employer_completed_at': '2026-10-01T10:00:00Z',
        'i_reviewed_them': false,
        'review_closes_at': closes,
        'job': {
          'id': 41,
          'title': 'Repaint a steel gate',
          'status': 'completed',
          'employer': {'id': 3, 'name': 'Rosa Bautista'},
        },
      };

  List<Map<String, dynamic>> items({
    List<Map<String, dynamic>> jobs = const [],
    List<Map<String, dynamic>> work = const [],
    bool worker = false,
  }) =>
      activeItems(
        AppModeProvider()..reconcile(hasWorker: worker, hasEmployer: !worker),
        ApplicationProvider()..seedApplications(work),
        JobProvider()..seedMyJobs(jobs),
      );

  test('a finished job waiting on your review stays in Active', () {
    expect(items(jobs: [finishedJob(closes: inDays(5))]), hasLength(1));
    expect(items(work: [finishedWork(closes: inDays(5))], worker: true), hasLength(1));
  });

  test('it leaves once reviewed, or once the window closes', () {
    expect(items(jobs: [finishedJob(closes: inDays(5), reviewed: true)]), isEmpty);
    expect(items(jobs: [finishedJob(closes: inDays(-30))]), isEmpty);
    expect(items(work: [finishedWork(closes: inDays(-30))], worker: true), isEmpty);
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> row) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: activeCard(row, () async {}, compact: true)),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('the employer reviews from the same card on home', (tester) async {
    await pump(tester, {...finishedJob(closes: inDays(5)), '_isJob': true});
    expect(find.text('Review Mang Tonyo'), findsOneWidget);
  });

  testWidgets('so does the worker', (tester) async {
    await pump(tester, {...finishedWork(closes: inDays(5)), '_isJob': false});
    expect(find.text('Review employer'), findsOneWidget);
  });

  testWidgets('a closed window offers nothing to press', (tester) async {
    await pump(tester, {...finishedJob(closes: inDays(-30)), '_isJob': true});
    expect(find.textContaining('Review'), findsNothing);
  });
}
