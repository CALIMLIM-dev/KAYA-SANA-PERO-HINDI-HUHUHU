import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/applications/widgets/application_card.dart';
import 'package:kaya_app/features/jobs/widgets/featured_job_card.dart';
import 'package:kaya_app/features/jobs/widgets/job_card_v2.dart';
import 'package:kaya_app/features/jobs/widgets/worker_card.dart';
import 'package:kaya_app/features/messaging/widgets/conversation_card.dart';
import 'package:kaya_app/features/notifications/widgets/notification_item.dart';

import 'support/render_harness.dart';

/*
    The cards, carrying content the size real content comes in.

    The screen sweep renders whole screens with empty providers, which catches
    a header that cannot fit itself and nothing else. Overflow is a content
    bug: a card is laid out around the length of text somebody imagined, and it
    breaks on the job title that runs to two lines, or the barangay whose name
    is longer than the one that was tested.

    Every string below is long on purpose, and long in the way Philippine
    addresses and company names actually are - "Barangay Nancayasan, Urdaneta
    City, Pangasinan" is not a stress test, it is an address.

    Checked at the two widths that matter and at the largest text the app
    allows, because those are the combinations nobody develops on and everybody
    ends up holding.
*/
void main() {
  const longTitle = 'Experienced mason needed for a two storey residential building';
  const longCompany = 'Santiago Construction and General Services Incorporated';
  const longPlace = 'Barangay Nancayasan, Urdaneta City, Pangasinan';
  const longName = 'Ricardo Bumanglag Dela Cruz Jr.';

  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget child, {
    required double textScale,
    required double width,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        complaints.add(text.split('\n').first.trim());
        return;
      }
      previous?.call(details);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      tester.view.physicalSize = Size(width * 2, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              // Cards live in a list, so they get the full width and as much
              // height as they ask for - the same constraints as in the app.
              body: ListView(children: [child]),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  final cards = <String, Widget>{
    'job card': JobCardV2(
      title: longTitle,
      company: longCompany,
      location: longPlace,
      salary: 'PHP 800 - 1,200/day',
      isVerified: true,
      postedTime: '2 hours ago',
      onTap: () {},
    ),
    'featured job card': FeaturedJobCard(
      title: longTitle,
      company: longCompany,
      location: longPlace,
      rating: '4.8',
      reviews: '37',
      salary: 'PHP 800 - 1,200/day',
      isUrgent: true,
      requiresVerification: true,
      category: 'Construction and masonry',
      distance: '3.4 km',
      requiredSkills: const ['Masonry', 'Tile setting', 'Plastering'],
    ),
    'worker card': WorkerCard(
      name: longName,
      primarySkill: 'Residential electrical installation and repair',
      location: longPlace,
      rating: '4.8',
      reviews: '37',
      isAvailable: true,
      isVerified: true,
      skills: const ['Wiring', 'Panel boards', 'Troubleshooting'],
      matchScore: 92,
      distanceKm: 3.4,
      rateLabel: 'PHP 700 - 900/day',
    ),
    'application card': ApplicationCard(
      jobTitle: longTitle,
      company: longCompany,
      location: longPlace,
      appliedDate: '12 August 2026',
      acceptedDate: '14 August 2026',
      status: 'accepted',
      salary: 'PHP 800 - 1,200/day',
      isVerified: true,
      hasReview: false,
      onTap: () {},
      onWithdraw: () {},
    ),
    'conversation card': ConversationCard(
      name: longName,
      isVerified: true,
      lastMessage: 'Good afternoon po, tanong ko lang kung available pa po '
          'yung trabaho ngayong linggo?',
      timestamp: 'Yesterday',
      unreadCount: 12,
      jobTitle: longTitle,
      avatarColor: Colors.blue,
      onTap: () {},
    ),
    'notification item': NotificationItem(
      type: NotificationType.application,
      title: 'Your application was accepted',
      message: '$longCompany accepted your application for $longTitle',
      timestamp: '3 hours ago',
      isRead: false,
      onTap: () {},
    ),
  };

  for (final entry in cards.entries) {
    for (final width in <double>[360, 320]) {
      for (final scale in <double>[1.0, 1.3]) {
        testWidgets(
          '${entry.key} holds long content at ${width.toInt()}px, text scale $scale',
          (tester) async {
            final complaints = await overflowsIn(
              tester,
              entry.value,
              textScale: scale,
              width: width,
            );

            expect(
              complaints,
              isEmpty,
              reason: '${entry.key} overflowed at ${width.toInt()}px, '
                  'text scale $scale:\n  ${complaints.join('\n  ')}',
            );
          },
        );
      }
    }
  }
}
