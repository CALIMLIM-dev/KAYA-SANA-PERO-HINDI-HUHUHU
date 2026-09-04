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

    These pump the real screens against a seeded /me and check the fields are
    not typeable, which is the assertion that was missing.
*/
void main() {
  Map<String, dynamic> lockedAccount() => {
        'id': 1,
        'name': 'Ricardo Bumanglag Dela Cruz Jr.',
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

  /// Every text field on screen that will actually take typing.
  Iterable<TextField> editableFields(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .where((f) => !f.readOnly && (f.enabled ?? true));

  testWidgets('worker setup shows the account name and will not take a new one',
      (tester) async {
    await tester.pumpWidget(wrap(const WorkerSetupFlowScreen(), lockedAccount()));
    await tester.pump();

    expect(find.text('Ricardo Bumanglag Dela Cruz Jr.'), findsOneWidget);
    expect(find.text('First Name *'), findsNothing);
    expect(find.text('Last Name *'), findsNothing);

    // The location picker is the one field still open on this step.
    for (final field in editableFields(tester)) {
      expect(field.controller?.text ?? '', isNot('Ricardo Bumanglag Dela Cruz Jr.'),
          reason: 'the name must not be sitting in a typeable field');
    }
  });

  testWidgets('worker setup still asks a new account for its name',
      (tester) async {
    await tester.pumpWidget(wrap(const WorkerSetupFlowScreen(), freshAccount()));
    await tester.pump();

    expect(find.text('First Name *'), findsOneWidget);
    expect(find.text('Last Name *'), findsOneWidget);
  });

  testWidgets('employer setup will not take a new name either', (tester) async {
    await tester
        .pumpWidget(wrap(const SetupEmployerProfileScreen(), lockedAccount()));
    await tester.pump();

    // Step one asks which kind of employer this is; the name lives on the
    // step after it.
    await tester.tapAt(tester.getCenter(find.text('Individual').first));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('Next').last));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('First Name *'), findsNothing);
    expect(find.text('Ricardo Bumanglag Dela Cruz Jr.'), findsWidgets);
  });
}
