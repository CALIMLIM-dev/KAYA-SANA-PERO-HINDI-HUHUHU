import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/models/job_model.dart';

/*
    What the job says about your standing on it.

    A finished job opened from History said "Application Pending". The server
    sent `completed`; the app's enum did not have it; the parser's fallback
    for anything unknown was `pending`. A test on the parse alone would have
    caught it, and now one does - for every value the server can send.
*/
void main() {
  Map<String, dynamic> payload(Map<String, dynamic> extra) => {
        'id': 1,
        'title': 'Fix a leaking pipe',
        'description': 'Kitchen sink',
        'status': 'completed',
        ...extra,
      };

  test('every status the server sends is read as itself', () {
    // The full set on the server: the applications.status enum plus the
    // "completed" migration. Add one there without adding it here and it
    // reads as "pending" again.
    const sent = {
      'pending': ApplicationStatus.pending,
      'accepted': ApplicationStatus.accepted,
      'rejected': ApplicationStatus.rejected,
      'withdrawn': ApplicationStatus.withdrawn,
      'completed': ApplicationStatus.completed,
    };

    for (final entry in sent.entries) {
      final job = Job.fromApi(payload({
        'has_applied': true,
        'application_status': entry.key,
      }));

      expect(job.applicationStatus, entry.value,
          reason: '"${entry.key}" must not fall back to something else');
    }
  });

  test('a completed job is completed, not pending', () {
    final job = Job.fromApi(payload({
      'has_applied': true,
      'application_status': 'completed',
    }));

    expect(job.applicationStatus, ApplicationStatus.completed);
    expect(job.applicationStatus, isNot(ApplicationStatus.pending));
  });

  test('no application means no standing', () {
    final job = Job.fromApi(payload({'has_applied': false}));

    expect(job.applicationStatus, isNull);
  });

  group('the job against its own dates', () {
    String d(int daysFromNow) =>
        DateTime.now().add(Duration(days: daysFromNow)).toIso8601String().substring(0, 10);

    test('a job for yesterday has ended', () {
      final job = Job.fromApi(payload({'status': 'open', 'start_date': d(-1)}));

      expect(job.hasEnded, isTrue);
      expect(job.phaseLabel, startsWith('Ended'));
    });

    test('a job for today is not over', () {
      final job = Job.fromApi(payload({'status': 'open', 'start_date': d(0)}));

      expect(job.hasEnded, isFalse);
      expect(job.phaseLabel, 'Today');
    });

    test('a job ahead says when it starts', () {
      final job = Job.fromApi(payload({'status': 'open', 'start_date': d(3)}));

      expect(job.hasEnded, isFalse);
      expect(job.hasStarted, isFalse);
      expect(job.phaseLabel, startsWith('Starts'));
    });

    test('a running job says when it ends', () {
      final job = Job.fromApi(payload({
        'status': 'open',
        'start_date': d(-2),
        'end_date': d(2),
      }));

      expect(job.hasStarted, isTrue);
      expect(job.hasEnded, isFalse);
      expect(job.phaseLabel, startsWith('Ends'));
    });

    /// end_date is null for a single-day job, not copied from start_date.
    test('a single-day job ends on its start date', () {
      final job = Job.fromApi(payload({
        'status': 'open',
        'start_date': d(-1),
        'end_date': null,
      }));

      expect(job.hasEnded, isTrue);
    });

    test('no dates, no phase', () {
      final job = Job.fromApi(payload({'status': 'open'}));

      expect(job.hasEnded, isFalse);
      expect(job.phaseLabel, isNull);
    });
  });
}
