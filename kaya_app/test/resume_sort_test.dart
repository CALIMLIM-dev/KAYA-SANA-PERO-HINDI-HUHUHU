import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/resume_sort.dart';

void main() {
  // In the server's Best Match order.
  final rows = <Map<String, dynamic>>[
    {'id': 'ana', 'distance_km': 9, 'worker_rating': '4.20', 'reviews_total': 3, 'jobs_completed': 2},
    {'id': 'ben', 'distance_km': 1, 'worker_rating': '4.90', 'reviews_total': 12, 'jobs_completed': 7},
    {'id': 'cy', 'distance_km': null, 'worker_rating': '4.90', 'reviews_total': 2, 'jobs_completed': 0},
  ];

  List<String> ids(ResumeSort s) => [for (final r in s.apply(rows)) r['id'] as String];

  test('Best Match keeps the server order', () => expect(ids(ResumeSort.best), ['ana', 'ben', 'cy']));
  test('Nearest puts an unknown distance last', () => expect(ids(ResumeSort.nearest), ['ben', 'ana', 'cy']));
  test('Highest Rated breaks a tie on more reviews', () => expect(ids(ResumeSort.rated), ['ben', 'cy', 'ana']));
  test('Most Jobs Done', () => expect(ids(ResumeSort.jobs), ['ben', 'ana', 'cy']));
}
