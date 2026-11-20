import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/features/jobs/widgets/job_list_card.dart';

void main() {
  group('the area circle', () {
    test('a barangay with a centre is drawn 1 km wide', () {
      final a = JobArea.fromPlace({'type': 'barangay', 'latitude': '15.9758', 'longitude': '120.5707'})!;
      expect([a.lat, a.lng, a.radiusMeters], [15.9758, 120.5707, 1000]);
    });

    test('a barangay without one falls back to its town, 3 km wide', () {
      final a = JobArea.fromPlace({
        'type': 'barangay',
        'latitude': null,
        'longitude': null,
        'parent': {'type': 'city', 'latitude': 15.97, 'longitude': 120.57},
      })!;
      expect(a.radiusMeters, 3000);
      expect(a.lat, 15.97);
    });

    test('no place, no circle', () {
      expect(JobArea.fromPlace(null), isNull);
      expect(JobArea.fromPlace({'type': 'city'}), isNull);
    });

    test('the job reads it from psgc_location', () {
      final job = Job.fromApi({
        'id': 1,
        'title': 'Ayos ng gripo',
        'status': 'open',
        'psgc_location': {'type': 'barangay', 'latitude': 15.9, 'longitude': 120.5},
      });
      expect(job.area?.radiusMeters, 1000);
    });
  });

  Widget card(Job job) => MaterialApp(
        home: Scaffold(
          body: ListView(children: [JobListCard(job: job, onTap: () {}, onToggleSave: () {})]),
        ),
      );

  Job job({List<String> photos = const []}) => Job(
        id: 1,
        title: 'Ayos ng gripo sa kusina',
        company: 'Santos Family',
        salaryMin: 4000,
        salaryPeriod: 'project',
        category: 'Plumbing',
        photoUrls: photos,
      );

  testWidgets('the employer photo fills the top, the price comes first', (tester) async {
    await tester.pumpWidget(card(job(photos: ['https://example.test/a.jpg', 'https://example.test/b.jpg'])));
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, 'https://example.test/a.jpg');
    // Decoded at the card's size, not the upload's.
    expect(image.memCacheWidth, isNotNull);
    expect(find.text('₱4,000/contract'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'how many photos the job has');
    expect(tester.getTopLeft(find.text('₱4,000/contract')).dy,
        lessThan(tester.getTopLeft(find.text('Ayos ng gripo sa kusina')).dy));
  });

  testWidgets('a post with no photo shows its trade, not a stand-in picture', (tester) async {
    await tester.pumpWidget(card(job()));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.plumbing), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
  });
}
