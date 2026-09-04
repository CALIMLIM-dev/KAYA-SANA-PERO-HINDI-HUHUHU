import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/employer/screens/setup_employer_profile_screen.dart';
import 'package:kaya_app/features/worker/screens/worker_setup_flow_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

/*
    One account, one name.

    Setting up the second profile is where a hybrid could type somebody else:
    both flows show name fields, and both were meant to freeze them once the
    account already had a name. They read `last_name` off the /me payload to
    decide, /me never sent it, and the lock was therefore off for every
    account that has ever opened these screens - including verified ones.

    The fields are still shown one per part, and in the order a Philippine
    form asks for them; what changes when the name is settled is that none of
    them takes typing.
*/
void main() {
  Map<String, dynamic> lockedAccount() => {
        'id': 1,
        'name': 'Ricardo B. Dela Cruz Jr.',
        'first_name': 'Ricardo',
        'middle_name': 'Bumanglag',
        'last_name': 'Dela Cruz',
        'suffix': 'Jr.',
        'name_locked': true,
        'is_verified': true,
        'email': 'ricardo@example.com',
        'worker_profile_exists': true,
        'worker_setup_completed': true,
        'employer_profile_exists': false,
        'employer_setup_completed': false,
      };

  Map<String, dynamic> freshAccount() => {
        'id': 2,
        'name': '',
        'first_name': null,
        'last_name': null,
        'name_locked': false,
        'is_verified': false,
        'email': 'new@example.com',
        'worker_profile_exists': false,
        'worker_setup_completed': false,
        'employer_profile_exists': false,
        'employer_setup_completed': false,
      };

  Widget wrap(Widget screen, Map<String, dynamic>? user) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..seedUser(user)),
        ChangeNotifierProvider(
            create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(home: screen),
    );
  }

  /// The name fields, found by their labels rather than by position.
  Finder fieldFor(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextField),
      );

  bool takesTyping(WidgetTester tester, String label) {
    final field = tester.widget<TextField>(fieldFor(label).first);
    return !field.readOnly && (field.enabled ?? true);
  }

  testWidgets('worker setup asks surname first and will not take a new name',
      (tester) async {
    await tester
        .pumpWidget(wrap(const WorkerSetupFlowScreen(), lockedAccount()));
    await tester.pump();

    // Every part is still labelled, so it is clear which is which.
    for (final label in const [
      'Last Name *',
      'First Name *',
      'Middle Name (optional)',
      'Suffix',
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(takesTyping(tester, label), isFalse,
          reason: '$label must not accept typing on a settled account');
    }

    // Surname above the given name, the way a Philippine form asks.
    expect(tester.getTopLeft(fieldFor('Last Name *').first).dy,
        lessThan(tester.getTopLeft(fieldFor('First Name *').first).dy));
  });

  testWidgets('worker setup still lets a new account type its name',
      (tester) async {
    await tester.pumpWidget(wrap(const WorkerSetupFlowScreen(), freshAccount()));
    await tester.pump();

    expect(takesTyping(tester, 'First Name *'), isTrue);
    expect(takesTyping(tester, 'Last Name *'), isTrue);
  });

  testWidgets('employer setup will not take a new name either', (tester) async {
    await tester
        .pumpWidget(wrap(const SetupEmployerProfileScreen(), lockedAccount()));
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.text('Individual').first));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('Next').last));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    for (final label in const ['Last Name *', 'First Name *']) {
      expect(find.text(label), findsOneWidget);
      expect(takesTyping(tester, label), isFalse,
          reason: '$label must not accept typing on a settled account');
    }
  });
  /*
      A worker account is not offered the business option at all.

      The server has always refused it, but the option was selectable, so the
      way to find out was to fill in the whole flow and be turned down on the
      last step.
  */
  testWidgets('a worker account cannot pick Company', (tester) async {
    await tester
        .pumpWidget(wrap(const SetupEmployerProfileScreen(), lockedAccount()));
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.text('Company').first));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('Next').last));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Still on the first step, with the reason on screen.
    expect(find.textContaining('stays Individual'), findsOneWidget);
    expect(find.text('Last Name *'), findsNothing);
  });
}
