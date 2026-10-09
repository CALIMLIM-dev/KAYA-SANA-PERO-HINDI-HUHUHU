import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/verification_badge_widget.dart';
import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/models/worker_profile_model.dart';

/*
    The panel: verified and unverified accounts identified clearly.

    Not verified has to be drawn, not left blank - blank reads as "did not
    load" - and somebody whose ID is with an admin is neither.
*/
void main() {
  group('reading the state', () {
    test('the server field wins', () {
      expect(VerificationState.of({'verification_state': 'pending', 'is_verified': false}),
          VerificationState.pending);
      expect(VerificationState.of({'verification_state': 'verified_business'}),
          VerificationState.verifiedBusiness);
    });

    test('an older payload falls back to the flag', () {
      expect(VerificationState.of({'is_verified': true}), VerificationState.verified);
      expect(VerificationState.of({'is_verified': false}), VerificationState.unverified);
      expect(VerificationState.of(null), VerificationState.unverified);
    });

    test('job and worker models carry it', () {
      final job = Job.fromApi({
        'id': 1,
        'title': 'Aircon cleaning',
        'employer': {'id': 4, 'name': 'Rosa', 'is_verified': false, 'verification_state': 'pending'},
      });
      expect(job.employerVerification, VerificationState.pending);

      final worker = WorkerProfile.fromApi({
        'id': 2,
        'name': 'Juan',
        'is_verified': true,
        'verification_state': 'verified',
      });
      expect(worker.verification, VerificationState.verified);
    });
  });

  testWidgets('every state is drawn in words', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          VerificationChip(state: VerificationState.verified),
          VerificationChip(state: VerificationState.verifiedBusiness),
          VerificationChip(state: VerificationState.pending),
          VerificationChip(state: VerificationState.unverified),
        ]),
      ),
    ));

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Verified business'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
  });
}
