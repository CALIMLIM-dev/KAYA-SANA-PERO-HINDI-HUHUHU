import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/notifications/notification_destination.dart';
import 'package:kaya_app/providers/notification_provider.dart';

/*
    Where a notification takes you.

    Every notification carries a reference_type, and the list routed on that
    alone. Two whole classes of them went to the wrong screen because of it:

      - A review is attached to the job it happened on, so being told you had
        been reviewed opened the public job advert, with an "Application
        pending" button on it and no review anywhere.

      - Every employer-side notification with a job reference opened that same
        public advert - the employer's own listing, as a worker sees it. An
        applicant withdrawing, an invitation accepted, a post about to expire:
        all of them landed on a page with an Apply button.

    The screen decides with `type` and `audience` together now. This pins the
    decision itself, so a change to the routing has to be deliberate.
*/
void main() {
  /// The real rule the screen routes on, not a copy of it.
  String destinationFor({
    required String type,
    required String audience,
    required String referenceType,
    int? referenceId,
  }) =>
      notificationDestination(
        type: type,
        audience: audience,
        referenceType: referenceType,
        referenceId: referenceId,
      ).name;

  test('a report about you opens the place to give your side', () {
    expect(
      destinationFor(type: 'report.filed', audience: 'both', referenceType: 'report', referenceId: 9),
      'reportResponse',
    );
  });

  test('a review takes the reviewed person to their own profile', () {
    expect(
      destinationFor(
        type: 'review.received',
        audience: 'worker',
        referenceType: 'job',
        referenceId: 7,
      ),
      'workerProfile',
    );

    expect(
      destinationFor(
        type: 'review.received',
        audience: 'employer',
        referenceType: 'job',
        referenceId: 7,
      ),
      'employerProfile',
    );
  });

  test('employer-side job notifications never open the public advert', () {
    for (final type in const [
      'application.withdrawn',
      'application.cancelled',
      'invitation.declined',
    ]) {
      expect(
        destinationFor(
          type: type,
          audience: 'employer',
          referenceType: 'job',
          referenceId: 7,
        ),
        'applicants',
        reason: '$type sent an employer to a page with an Apply button',
      );
    }
  });

  /*
      A hire, and a post an admin closed, open My Jobs.

      The applicants list opens on Pending, where somebody who just took the
      job by invitation is not - they are on the job's card in My Jobs, with
      Message and Mark as complete. A closed post is in My Jobs' History.
  */
  test('a hire by invitation and a closed post open My Jobs', () {
    for (final type in const ['invitation.accepted', 'job.closed']) {
      expect(
        destinationFor(type: type, audience: 'employer', referenceType: 'job', referenceId: 7),
        'manageJobs',
        reason: type,
      );
    }
  });

  /*
      Nothing to open: the words are the point. These opened the
      notification list, which from the list itself stacked a second copy
      of it - the "back twice" report.
  */
  test('a warning, an outcome or an announcement shows its words, not another list', () {
    for (final type in const [
      'moderation.warning',
      'report.decided',
      'report.closed',
      'announcement.sent',
    ]) {
      expect(
        notificationDestination(type: type, audience: 'both', referenceType: null).name,
        'fullText',
        reason: type,
      );
    }
  });

  test('every other kind has a place to go', () {
    expect(destinationFor(type: 'support.replied', audience: 'both', referenceType: ''), 'support');
    expect(destinationFor(type: 'badge.earned', audience: 'worker', referenceType: ''), 'workerProfile');
    expect(destinationFor(type: 'badge.earned', audience: 'employer', referenceType: ''), 'employerProfile');
    expect(
      destinationFor(type: 'community.removed', audience: 'worker', referenceType: 'community_post', referenceId: 4),
      'communityPost',
    );
    expect(
      destinationFor(type: 'work_again.requested', audience: 'employer', referenceType: 'user', referenceId: 8),
      'person',
    );
    expect(
      destinationFor(type: 'message.received', audience: 'both', referenceType: 'conversation', referenceId: 3),
      'chat',
    );
    expect(
      destinationFor(type: 'invitation.received', audience: 'worker', referenceType: 'invitation', referenceId: 2),
      'invitations',
    );
  });

  test('expiry takes the employer where extending is', () {
    for (final type in const ['job.expiring', 'job.expired']) {
      expect(
        destinationFor(
          type: type,
          audience: 'employer',
          referenceType: 'job',
          referenceId: 7,
        ),
        'manageJobs',
      );
    }
  });

  test('a worker still gets the job page for a job notification', () {
    expect(
      destinationFor(
        type: 'job.match',
        audience: 'worker',
        referenceType: 'job',
        referenceId: 7,
      ),
      'jobDetails',
    );
  });

  /*
      Live work opens the Active screen, from either side.

      It opened My Activity, which only keeps what is over now - a hired
      worker would land on History looking for a job still running. The
      employer's copy went to Manage Jobs, which has no Mark as complete.
  */
  test('hired and completion nudges open live work, on each side', () {
    for (final type in ['application.accepted', 'application.completion_pending']) {
      expect(
        destinationFor(type: type, audience: 'worker', referenceType: 'application', referenceId: 3),
        'active',
        reason: '$type for the worker',
      );
    }

    // An employer's running posts are My Jobs, not Home's Active list.
    expect(
      destinationFor(
        type: 'application.completion_pending',
        audience: 'employer',
        referenceType: 'application',
        referenceId: 3,
      ),
      'manageJobs',
    );

    // A finished job waits in Active for the worker's review.
    expect(
      destinationFor(type: 'job.completed', audience: 'worker', referenceType: 'job', referenceId: 7),
      'active',
    );

    // Anything else about an application is not live work.
    expect(
      destinationFor(
        type: 'application.rejected',
        audience: 'worker',
        referenceType: 'application',
        referenceId: 3,
      ),
      'applications',
    );
  });

  test('the payload the routing reads survives a parse', () {
    final n = AppNotification.fromJson(const {
      'id': 1,
      'type': 'review.received',
      'audience': 'employer',
      'title': 'You have a new review',
      'body': 'Somebody reviewed you',
      'reference_type': 'job',
      'reference_id': 7,
      'is_read': false,
    });

    expect(n.type, 'review.received');
    expect(n.audience, 'employer');
    expect(n.referenceType, 'job');
    expect(n.referenceId, 7);
  });
}
