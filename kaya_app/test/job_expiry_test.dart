import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/models/job_model.dart';

/*
    A job post has a life now, and the app has to read it.

    The server sweep that writes `status` runs once a day and the date is
    exact, so a post can be past due while still saying "open". Anything that
    decides whether a job is live has to read the date, which means the date
    has to survive the parse - it is the kind of field that gets added to a
    payload and quietly dropped on the way in.
*/
void main() {
  Map<String, dynamic> payload(Map<String, dynamic> extra) => {
        'id': 1,
        'title': 'Fix a leaking pipe',
        'description': 'Kitchen sink',
        'status': 'open',
        ...extra,
      };

  test('the expiry date is read from the payload', () {
    final job = Job.fromApi(payload({
      'expires_at': DateTime.now().add(const Duration(days: 9)).toIso8601String(),
    }));

    expect(job.expiresAt, isNotNull);
    expect(job.daysUntilExpiry, 9);
  });

  test('a post with no date has none, rather than a wrong one', () {
    final job = Job.fromApi(payload({}));

    expect(job.expiresAt, isNull);
    expect(job.daysUntilExpiry, isNull);
  });

  /*
        Past due reads as past due even while the status still says open -
        which is exactly the state a post is in between lapsing and the next
        morning's sweep.
    */
  test('a lapsed post counts down past zero', () {
    final job = Job.fromApi(payload({
      'status': 'open',
      'expires_at':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    }));

    expect(job.daysUntilExpiry, lessThan(0));
  });

  test('garbage in the field does not throw', () {
    final job = Job.fromApi(payload({'expires_at': 'not a date'}));

    expect(job.expiresAt, isNull);
  });
}
