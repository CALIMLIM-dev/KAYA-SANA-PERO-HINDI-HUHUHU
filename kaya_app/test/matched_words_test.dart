import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/features/applications/widgets/applicant_card.dart';
import 'package:kaya_app/features/applications/widgets/fit_facts.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

/*
    Different words, one check. The System linked the worker's "Tubero" and
    the employer's "Ayos ng tagas" to the same skill; each side sees its own
    words with a check, never renamed.
*/
void main() {
  final row = <String, dynamic>{
    'application_id': 1,
    'application_status': 'pending',
    'worker_id': 7,
    'worker_name': 'Juan Dela Cruz',
    'is_premium': true,
    'skills': ['Tubero', 'Leak Detection'],
    'required_count': 1,
    'matched_count': 1,
    'matched_skills': ['ayos ng tagas'],
    'matched_pairs': [
      {'required': 'Ayos ng tagas', 'held': 'Tubero'},
    ],
    'match_tier': 2,
  };

  test('the pairs are read, and only differing words get a line', () {
    expect(matchedHeld(row), {'tubero'});
    expect(differentWords(row).single.held, 'Tubero');
    expect(differentWords({'matched_pairs': [{'required': 'Laundry', 'held': 'laundry'}]}), isEmpty);
  });

  testWidgets('the employer sees the worker\'s own word ticked and what it met', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ApplicantCard(applicant: row, showActions: false, perWorkerActions: false, onChanged: () async {}),
          ),
        ),
      ),
    ));

    expect(find.text('Tubero matches your "Ayos ng tagas"'), findsOneWidget);
    expect(find.text('Tubero'), findsOneWidget, reason: 'never renamed');
  });

  test('the worker\'s job carries which of their skills met each requirement', () {
    final job = Job.fromApi({
      'id': 1,
      'title': 'Tagas sa lababo',
      'description': 'x',
      'skills': [
        {'id': 3, 'name': 'Ayos ng tagas'},
      ],
      'matched_skills': ['ayos ng tagas'],
      'matched_pairs': [
        {'required': 'Ayos ng tagas', 'held': 'Tubero'},
      ],
    });

    expect(job.matchedPairs['ayos ng tagas'], 'Tubero');
  });
}
