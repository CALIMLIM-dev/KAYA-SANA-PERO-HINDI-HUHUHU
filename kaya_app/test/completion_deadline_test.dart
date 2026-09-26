import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/features/applications/widgets/completion_action.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    Mark as complete does not exist before the job's deadline.

    The button was available from the moment somebody was hired, so a job
    booked for next month could be declared finished on the afternoon it was
    posted. It now appears on the job's last day and not before, and the card
    says when that is instead of leaving a gap.

    The server refuses the same call, so this is the screen agreeing with it
    rather than the only thing holding the rule.
*/
void main() {
  String day(int offset) => DateTime.now()
      .add(Duration(days: offset))
      .toIso8601String()
      .split('T')
      .first;

  Map<String, dynamic> hire({String? start, String? end}) => {
        'id': 77,
        'status': 'accepted',
        'conversation_id': 12,
        'worker_completed_at': null,
        'employer_completed_at': null,
        'i_reviewed_them': false,
        'they_reviewed_me': false,
        'job': {
          'id': 5,
          'title': 'Carpenter for built in cabinet installation',
          'category': {'id': 3, 'name': 'Carpentry'},
          'city': 'Urdaneta City, Pangasinan',
          'budget_min': 900,
          'budget_max': 1200,
          'status': 'in_progress',
          'start_date': start,
          'end_date': end,
          'employer': {'id': 9, 'name': 'Santiago Construction', 'is_verified': true},
        },
      };

  Widget screen(Map<String, dynamic> application) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModeProvider>.value(
          value: AppModeProvider()..reconcile(hasWorker: true, hasEmployer: false),
        ),
        ChangeNotifierProvider<ApplicationProvider>.value(
          value: ApplicationProvider()..seedApplications([application]),
        ),
        ChangeNotifierProvider<InvitationProvider>.value(
          value: InvitationProvider()..seedInvitations([]),
        ),
        ChangeNotifierProvider<JobProvider>.value(value: JobProvider()..seedMyJobs([])),
      ],
      child: const MaterialApp(home: ApplicationsScreen()),
    );
  }

  Future<void> render(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a hire whose deadline is still ahead offers no completion',
      (tester) async {
    await render(tester, screen(hire(start: day(3), end: day(9))));

    expect(find.text('Mark as complete'), findsNothing,
        reason: 'the work is not due to be finished for another nine days');
    // Not just when, but the way out: somebody finished early needs to
    // know agreeing today in the chat moves the day, which it does.
    expect(find.textContaining('Finished early?'), findsWidgets,
        reason: 'the card has to say when it appears and how to bring it forward');
    expect(find.textContaining('Agree the day in the chat'), findsWidgets);
  });

  testWidgets('the deadline day itself offers completion', (tester) async {
    await render(tester, screen(hire(start: day(0), end: day(0))));

    expect(find.text('Mark as complete'), findsWidgets,
        reason: 'a one day job finishes during the day, not at midnight');
    expect(find.textContaining('Finished early?'), findsNothing);
  });

  testWidgets('a job posted before schedules existed is not held to a deadline',
      (tester) async {
    await render(tester, screen(hire()));

    expect(find.text('Mark as complete'), findsWidgets);
  });

  test('the Job model reads the deadline the same way', () {
    Job at({DateTime? start, DateTime? end}) => Job(
          id: 1,
          title: 'x',
          company: 'Santiago Construction',
          description: 'x',
          employerId: 2,
          status: 'in_progress',
          startDate: start,
          endDate: end,
        );

    final today = DateTime.now();
    final soon = today.add(const Duration(days: 4));

    expect(at(start: today, end: soon).completionHasOpened, isFalse);
    expect(at(start: today, end: soon).deadlineNote, contains('opens that day'));

    // One day, today. The last day counts.
    expect(at(start: today).completionHasOpened, isTrue);
    expect(at(start: today).deadlineNote, isNull);

    // No dates at all.
    expect(at().completionHasOpened, isTrue);
  });

  test('the map helper agrees with the model', () {
    expect(completionHasOpened({'start_date': day(2), 'end_date': day(5)}), isFalse);
    expect(completionHasOpened({'start_date': day(0)}), isTrue);
    expect(completionHasOpened({'start_date': day(-5), 'end_date': day(-1)}), isTrue);
    expect(completionHasOpened(null), isTrue);
    expect(jobDeadline({'start_date': day(1), 'end_date': day(6)}),
        DateTime.parse(day(6)));
  });
}
