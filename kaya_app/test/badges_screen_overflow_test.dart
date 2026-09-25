import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/profile/screens/badges_screen.dart';

import 'support/render_harness.dart';

/*
    The badge catalogue, with a reward pill on every row.

    Each tile is a medallion, a label, a requirement, a progress line and now
    a "+5" pill saying what the badge pays. That is five things across one row
    on a phone, and the pill is what pushed it over - which is exactly the
    kind of change that passes every test written against an empty screen.
*/
void main() {
  Map<String, dynamic> badge({
    required String code,
    required String label,
    required String requirement,
    required String progress,
    required int reward,
    bool earned = false,
    bool paid = false,
  }) =>
      {
        'code': code,
        'label': label,
        'requirement': requirement,
        'progress': progress,
        'reward': reward,
        'reward_paid': paid,
        'earned': earned,
        'description': earned ? '4.8 average across 6 reviews' : null,
      };

  Map<String, List<Map<String, dynamic>>> catalogue() => {
        'account': [
          badge(
            code: 'verified',
            label: 'Verified',
            requirement: 'Have a government ID approved by KAYA',
            progress: 'Not submitted yet',
            reward: 10,
            earned: true,
            paid: true,
          ),
          badge(
            code: 'veteran',
            label: 'Veteran',
            requirement: 'Be on KAYA for a year',
            progress: '7 months so far',
            reward: 15,
          ),
        ],
        'worker': [
          badge(
            code: 'first_job',
            label: 'First Job',
            requirement: 'Finish your first job',
            progress: '0 finished',
            reward: 5,
          ),
          badge(
            code: 'jobs_50',
            label: '50 Jobs',
            requirement: 'Finish 50 jobs',
            progress: '3 of 50',
            reward: 60,
          ),
          badge(
            code: 'highly_rated',
            label: 'Highly Rated',
            requirement: 'Keep a 4.5 average across at least 5 reviews',
            progress: '4.2 average across 6 reviews',
            reward: 30,
            earned: true,
          ),
          badge(
            code: 'reliable',
            label: 'Reliable',
            requirement: 'Finish at least 90 percent of the jobs you take, '
                'across 5 or more, with 3 different verified employers',
            progress: '80 percent across 5 finished',
            reward: 30,
          ),
        ],
        'employer': [
          badge(
            code: 'jobs_10',
            label: '10 Hires',
            requirement: 'Complete 10 hires',
            progress: '2 of 10',
            reward: 20,
          ),
          badge(
            code: 'repeat_hire',
            label: 'Repeat Hire',
            requirement: 'Hire the same worker twice',
            progress: 'Nobody hired twice yet',
            reward: 15,
          ),
        ],
      };

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required double width,
    required double textScale,
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

      tester.view.physicalSize = Size(width * 2, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(home: BadgesScreen(seed: catalogue())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Nothing below is worth believing if the list never drew. The
      // first tile is the one on screen at every width; the long ones
      // further down are reached by scrolling, which is the point.
      expect(find.text('Verified'), findsWidgets,
          reason: 'the catalogue never rendered, so nothing was checked');
      expect(find.textContaining('+10 paid'), findsWidgets,
          reason: 'the reward pill is the part this test exists for');

      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pump(const Duration(milliseconds: 120));
      }

      // The longest requirement in the catalogue, with its own pill, laid
      // out rather than skipped over.
      expect(find.text('Reliable'), findsWidgets,
          reason: 'scrolling never reached the tiles this test is about');
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets(
        'the badge catalogue fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(tester, width: width, textScale: scale);

          expect(complaints, isEmpty,
              reason: 'Badges overflowed at ${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}');
        },
      );
    }
  }
}
