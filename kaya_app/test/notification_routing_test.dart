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
      'invitation.accepted',
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

  test('the completion nudge splits by side', () {
    expect(
      destinationFor(
        type: 'application.completion_pending',
        audience: 'worker',
        referenceType: 'application',
        referenceId: 3,
      ),
      'applications',
    );

    // The employer's copy used to go to My Applications, a worker screen,
    // which an employer-only account is then refused entry to.
    expect(
      destinationFor(
        type: 'application.completion_pending',
        audience: 'employer',
        referenceType: 'application',
        referenceId: 3,
      ),
      'manageJobs',
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
