import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/models/job_model.dart';

void main() {
  Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
        'id': 1,
        'title': 'Ayos ng gripo',
        'description': 'Tumutulo',
        'budget_min': 800,
        'budget_period': 'project',
        'status': 'open',
        'created_at': '2026-11-19T08:00:00Z',
        ...extra,
      };

  test('a job with an estimated start says when', () {
    final job = Job.fromApi(row({'work_starts_on': '2026-11-25'}));
    expect(job.startsLabel, 'Starts Nov 25');
    expect(job.payUnit, '/contract');
  });

  test('a job without one says nothing', () {
    expect(Job.fromApi(row()).startsLabel, isNull);
  });
}
