import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    A number on a card has to match the list it opens.

    The home screen counted applications with status 'pending'. The screen it
    opens lists 'pending' and 'accepted'. So being hired moved an application
    out of the count while leaving it in the list, and the card read 0 over a
    screen with something on it.

    Nothing was broken in either place on its own — the rule simply existed
    twice, and only one copy was updated when 'accepted' was added. That is
    the failure this file is about: not a wrong filter, but a duplicated one.

    So these tests are written against the providers' own getters rather than
    against the widgets. If a screen ever goes back to filtering inline, these
    still pass and the bug comes back, which is worth knowing — the guard that
    actually holds is that both sides read the same getter.
*/
void main() {
  Map<String, dynamic> application(String status) => {
        'id': status.hashCode,
        'status': status,
        'job': {'title': 'Mason needed'},
      };

  Map<String, dynamic> job(String status) => {
        'id': status.hashCode,
        'status': status,
        'title': 'Mason needed',
      };

  group('applications', () {
    test('active covers pending and accepted, and nothing else', () {
      final provider = ApplicationProvider()
        ..seedApplications([
          application('pending'),
          application('accepted'),
          application('rejected'),
          application('withdrawn'),
          application('completed'),
        ]);

      expect(
        provider.active.map((a) => a['status']),
        containsAll(<String>['pending', 'accepted']),
        reason: 'The applications screen lists pending and accepted under '
            'Active. Anything the card counts differently is a number that '
            'disagrees with the list underneath it.',
      );
      expect(provider.active, hasLength(2));
    });

    /*
        The reported symptom, reduced.

        One accepted application and nothing else: the card used to say 0
        while the screen showed 1.
    */
    test('an accepted application still counts as active', () {
      final provider = ApplicationProvider()
        ..seedApplications([application('accepted')]);

      expect(
        provider.active,
        hasLength(1),
        reason: 'Getting hired emptied the count while the application was '
            'still listed, so the card read 0 over a screen with one row.',
      );
    });

    test('the three buckets between them lose nothing', () {
      final all = [
        application('pending'),
        application('accepted'),
        application('completed'),
        application('rejected'),
        application('withdrawn'),
      ];
      final provider = ApplicationProvider()..seedApplications(all);

      final bucketed = <dynamic>{
        ...provider.active.map((a) => a['id']),
        ...provider.completed.map((a) => a['id']),
        ...provider.history.map((a) => a['id']),
      };

      expect(
        bucketed,
        hasLength(all.length),
        reason: 'An application in no tab is invisible to the worker who made '
            'it, with nothing on screen to say it exists.',
      );
    });
  });

  group('jobs', () {
    test('activeJobs covers open and in_progress, and nothing else', () {
      final provider = JobProvider()
        ..seedMyJobs([
          job('open'),
          job('in_progress'),
          job('completed'),
          job('closed'),
        ]);

      expect(
        provider.activeJobs.map((j) => j['status']),
        containsAll(<String>['open', 'in_progress']),
        reason: 'manage_jobs_screen treats open and in_progress as active. '
            'The home card has to agree with it.',
      );
      expect(provider.activeJobs, hasLength(2));
    });
  });
}
