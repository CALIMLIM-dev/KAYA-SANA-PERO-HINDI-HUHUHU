import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/core/constants/app_version.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/screens/settings_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Settings, grouped: help and the legal pages moved in from the profile
    tab, the real version shown, and one row for leaving that offers each
    side separately when the account holds both.
*/
void main() {
  Future<void> render(WidgetTester tester, {required bool worker, required bool employer}) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final auth = AuthProvider()
      ..seedUser({
        'id': 1,
        'name': 'Ana Reyes',
        'worker_profile_exists': worker,
        'employer_profile_exists': employer,
      });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();
  }

  // The preferences request is still out when a test ends; let it time out.
  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('help, legal and the real version are in Settings', (tester) async {
    await render(tester, worker: true, employer: false);

    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('FAQs'), findsOneWidget);
    expect(find.text('Message KAYA Support'), findsOneWidget);
    expect(find.text('About & Legal'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text(AppVersion.current), findsOneWidget);
    await drain(tester);
  });

  testWidgets('one side only: the row goes straight to deleting the account', (tester) async {
    await render(tester, worker: true, employer: false);

    await tester.scrollUntilVisible(find.text('Delete Account'), 200);
    expect(find.text('Delete Account or a Profile'), findsNothing);
    await drain(tester);
  });

  testWidgets('both sides: the row offers either side, or everything', (tester) async {
    await render(tester, worker: true, employer: true);

    await tester.scrollUntilVisible(find.text('Delete Account or a Profile'), 200);
    // Fully on screen, not just its top edge, so the tap lands on it.
    await tester.ensureVisible(find.text('Delete Account or a Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account or a Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Worker Profile'), findsOneWidget);
    expect(find.text('Remove Employer Profile'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    await tester.tap(find.text('Remove Employer Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Your Employer Profile?'), findsOneWidget);
    expect(find.textContaining('your reviews stay'), findsOneWidget);
    await drain(tester);
  });
}
