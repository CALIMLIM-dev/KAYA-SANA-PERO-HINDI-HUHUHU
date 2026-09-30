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
    Before the deadline, finishing a job takes the other side's agreement.

    This file used to assert that the control did not exist until the
    deadline, and the reason was sound: the button was there from the moment
    somebody was hired, so a job booked for next month could be declared
    finished on the afternoon it was posted.

    Hiding it was the wrong cure. Completion already takes both sides -
    JobCompletionService stamps one and the job finishes only when both stamps
    are in - so nobody could ever finish a job alone, whatever the date. What
    hiding the control actually prevented was a pair who had finished the work
    early agreeing that they had. A fortnight's job done in three days left
    both of them looking at a button that was not there, with nothing to do
    but propose a new schedule to move a date that was never the point.

    So the control is there as soon as somebody is hired, and the deadline
    decides what it says: before it, it asks the other side; on and after it,
    it reads as it always did. A lone confirmation before the deadline waits
    for agreement, and kaya:settle-overdue-jobs is what eventually takes
    silence for it - a week after the deadline, not on the day of hire.
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

  testWidgets('a hire whose deadline is still ahead can still be finished',
      (tester) async {
    /*
        The reversal. The work might be done; the button is how they say so,
        and the other side still has to agree before anything completes.
    */
    await render(tester, screen(hire(start: day(3), end: day(9))));

    expect(find.text('Mark as Complete'), findsWidgets,
        reason: 'a pair who finished early had no way to say so');

    // And the card still says when it is due, so nobody has to guess.
    expect(find.textContaining('Due'), findsWidgets);
  });

  testWidgets('the deadline day itself offers completion', (tester) async {
    await render(tester, screen(hire(start: day(0), end: day(0))));

    expect(find.text('Mark as Complete'), findsWidgets,
        reason: 'a one day job finishes during the day, not at midnight');
  });

  testWidgets('a job posted before schedules existed is not held to a deadline',
      (tester) async {
    await render(tester, screen(hire()));

    expect(find.text('Mark as Complete'), findsWidgets);
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
    // The note says the date. It used to also tell people to go and move
    // it in the chat, which is no longer what anybody has to do.
    expect(at(start: today, end: soon).deadlineNote, contains('Due'));

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
