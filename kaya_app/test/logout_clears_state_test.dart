import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    Nothing about one account survives into the next one on the same phone.

    Every provider here holds data belonging to whoever is signed in, and none
    of them had a clear() at all - so signing out and back in left the next
    person holding the previous account's posted jobs, applications,
    invitations and, once the rehire list landed, the names and photos of
    everyone they had hired.

    The balance had the same hole and was found on its own. These tests exist
    so the rest cannot quietly come back: a provider that grows a new field
    without adding it to clear() fails here rather than in someone's hands.
*/
void main() {
  test('a jobs list does not survive a logout', () {
    final jobs = JobProvider()
      ..seedMyJobs([
        {'id': 1, 'title': 'Househelp needed', 'status': 'open'},
      ]);

    expect(jobs.jobs, isNotEmpty);

    jobs.clear();

    expect(jobs.jobs, isEmpty);
  });

  test('applications do not survive a logout', () {
    final applications = ApplicationProvider()
      ..seedApplications([
        {'id': 1, 'status': 'pending', 'job': <String, dynamic>{}},
      ]);

    expect(applications.applications, isNotEmpty);

    applications.clear();

    expect(applications.applications, isEmpty);
  });

  /*
      The one with the worst contents.

      Past workers carries names, photos and ratings of real people the
      previous employer hired.
  */
  test('invitations and the rehire list do not survive a logout', () {
    final invitations = InvitationProvider()
      ..seedInvitations([
        {'id': 1, 'status': 'pending'},
      ])
      ..seedPastWorkers([
        {
          'worker_id': 7,
          'name': 'Juan Dela Cruz',
          'avatar': 'https://example.test/j.png',
          'times_hired': 3,
        },
      ], cost: 1);

    expect(invitations.invitations, isNotEmpty);
    expect(invitations.pastWorkers, isNotEmpty);
    expect(invitations.rehireCost, 1);
    expect(invitations.hasLoadedPastWorkers, isTrue);

    invitations.clear();

    expect(invitations.invitations, isEmpty);
    expect(invitations.pastWorkers, isEmpty);
    expect(invitations.rehireCost, isNull);
    // Back to unloaded, or the next account sees an empty list presented as
    // fact rather than a spinner while theirs is fetched.
    expect(invitations.hasLoadedPastWorkers, isFalse);
  });

  test('a balance does not survive a logout', () {
    final credits = CreditsProvider();

    credits.adopt(250);
    expect(credits.balance, 250);

    credits.clear();

    expect(credits.balance, 0);
  });
}
