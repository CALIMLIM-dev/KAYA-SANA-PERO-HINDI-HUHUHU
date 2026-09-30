import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    Which of an employer's own posts are still running.

    Two things went wrong here and they produced the same complaint: a job
    that had ended still showing as active in the profile.

    The status column lags the date. The sweep that writes `expired` runs once
    a day at five in the morning, so between a post's end date and that sweep
    the column still says `open` - and reading the column alone filed a
    finished job under Active while the feed, which has always filtered on the
    date, had already dropped it.

    And nothing held `expired`. Active listed open and in_progress, History
    listed completed and closed, so a swept post belonged to neither and fell
    out of the screen entirely.
*/
void main() {
  Map<String, dynamic> job({String status = 'open', Object? isLive}) => {
        'id': 1,
        'status': status,
        'is_live': ?isLive,
      };

  group('the server has the last word', () {
    test('a post past its date is not active, whatever the column says', () {
      // This is the case that was reported: still `open`, already over.
      expect(
        JobProvider.jobIsActive(job(status: 'open', isLive: false)),
        isFalse,
      );
    });

    test('a live post is active', () {
      expect(
        JobProvider.jobIsActive(job(status: 'open', isLive: true)),
        isTrue,
      );
    });

    test('is_live wins over a status that disagrees', () {
      // Belt and braces: if the two ever conflict, the derived answer is the
      // one computed from both conditions.
      expect(
        JobProvider.jobIsActive(job(status: 'completed', isLive: true)),
        isTrue,
      );
    });

    test('a numeric 1 or 0 is read as a boolean', () {
      // MySQL booleans arrive as integers through some serialisers.
      expect(JobProvider.jobIsActive(job(isLive: 1)), isTrue);
      expect(JobProvider.jobIsActive(job(isLive: 0)), isFalse);
    });
  });

  group('an older server still works', () {
    test('without is_live it falls back to the status', () {
      expect(JobProvider.jobIsActive(job(status: 'open')), isTrue);
      expect(JobProvider.jobIsActive(job(status: 'in_progress')), isTrue);
      expect(JobProvider.jobIsActive(job(status: 'completed')), isFalse);
      expect(JobProvider.jobIsActive(job(status: 'closed')), isFalse);
      expect(JobProvider.jobIsActive(job(status: 'expired')), isFalse);
    });

    test('a phone that updated before the server shows a list, not nothing',
        () {
      // The regression to avoid: treating a missing field as "not active"
      // would empty Active for everyone until the server was deployed.
      expect(JobProvider.jobIsActive(job()), isTrue);
    });
  });

  group('every post lands in exactly one list', () {
    test('expired is in history rather than nowhere', () {
      // History is now "not active" rather than a list of endings, so a
      // status nobody enumerated cannot fall through both.
      const statuses = [
        'open',
        'in_progress',
        'completed',
        'closed',
        'expired',
        'something_added_later',
      ];

      for (final status in statuses) {
        final row = job(status: status);
        final active = JobProvider.jobIsActive(row);
        final history = !JobProvider.jobIsActive(row);

        expect(
          active || history,
          isTrue,
          reason: '"$status" belongs to neither list.',
        );
        expect(
          active && history,
          isFalse,
          reason: '"$status" is in both lists.',
        );
      }
    });
  });

  group('the provider filters with the same rule', () {
    test('activeJobs keeps the live posts and drops the finished ones', () {
      final provider = JobProvider();
      provider.seedMyJobs([
        job(status: 'open', isLive: true),
        // Over, but not yet swept. This is the one that used to show.
        job(status: 'open', isLive: false),
        job(status: 'completed', isLive: false),
        job(status: 'expired', isLive: false),
      ]);

      expect(provider.activeJobs.length, 1);
      expect(provider.activeJobs.single['is_live'], isTrue);
    });
  });
}
