import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/features/applications/widgets/applicant_card.dart';
import 'package:kaya_app/features/applications/widgets/fit_facts.dart';
import 'package:kaya_app/providers/application_provider.dart';

import 'support/render_harness.dart';

/*
    Fit, said as facts instead of a percentage.

    "72% match" could not be checked and could contradict the order a list
    was in. Every card now states what the order is built on: how many of
    the required skills the person has, whether they share the trade, and
    how far away they are - and a newcomer is tagged, not pushed down.
*/
void main() {
  Map<String, dynamic> applicant({
    int required = 2,
    int matched = 1,
    bool sameTrade = true,
    bool isNew = false,
    bool premium = false,
  }) =>
      {
        'application_id': 1,
        'application_status': 'pending',
        'worker_id': 101,
        'worker_name': 'Eddison Calimlim',
        'worker_rating': '4.90',
        'worker_rating_count': isNew ? 0 : 12,
        'is_verified': true,
        'skills': ['LCD Replacement', 'Battery Replacement'],
        'is_premium': premium,
        'match_tier': matched > 0 ? 2 : 1,
        'required_count': required,
        'matched_count': matched,
        'matched_skills': ['lcd replacement'],
        'same_trade': sameTrade,
        'distance_label': 'About 3 km away',
        'is_new': isNew,
      };

  test('the employer line names the skills, the trade and the distance', () {
    expect(
      employerFitLine(applicant()),
      'Required skills: 1 of 2 (LCD Replacement) · Same trade · About 3 km away',
    );
  });

  test('a job naming no skills says nothing about skills', () {
    expect(
      employerFitLine(applicant(required: 0, matched: 0)),
      'Same trade · About 3 km away',
    );
  });

  test('the worker line counts the skills, and says the trade when none are asked for', () {
    Job job({int? tier, int required = 0, int matched = 0}) => Job(
          id: 1,
          title: 'Fix a phone screen',
          company: 'Rosa',
          location: 'Urdaneta City',
          salaryMin: 500,
          salaryMax: 500,
          salaryPeriod: 'day',
          matchTier: tier,
          requiredCount: required,
          matchedCount: matched,
        );

    expect(job(tier: 2, required: 2, matched: 1).fitLine, 'You have 1 of 2 required skills');
    expect(job(tier: 2, required: 1, matched: 1).fitLine, 'You have 1 of 1 required skill');
    expect(job(tier: 2).fitLine, 'Matches your trade');
    expect(job(tier: 0).fitLine, isNull);
    expect(job().fitLine, isNull, reason: 'no worker profile, nothing true to say');
  });

  Future<void> pump(WidgetTester tester, Widget card, {double width = 412, double scale = 1.0}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => ApplicationProvider(),
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: card))),
      ),
    ));
    await tester.pump();
  }

  ApplicantCard card(Map<String, dynamic> row) => ApplicantCard(
        applicant: row,
        rank: 1,
        showActions: true,
        perWorkerActions: false,
        onChanged: () async {},
      );

  for (final premium in [false, true]) {
    final layout = premium ? 'resume card' : 'compact card';

    testWidgets('the $layout states the fit and tags a newcomer', (tester) async {
      await pump(tester, card(applicant(isNew: true, premium: premium)));

      expect(find.textContaining('Required skills: 1 of 2'), findsOneWidget);
      expect(find.text('New on KAYA'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    for (final width in <double>[360, 320]) {
      testWidgets('the $layout fits ${width.toInt()}px at scale 1.3', (tester) async {
        final complaints = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            complaints.add(d.exceptionAsString().split('\n').first);
            return;
          }
          previous?.call(d);
        };
        try {
          await pump(tester, card(applicant(isNew: true, premium: premium)), width: width, scale: 1.3);
        } finally {
          FlutterError.onError = previous;
        }

        expect(find.textContaining('Required skills'), findsOneWidget);
        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
