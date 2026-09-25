import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/screens/post_job_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Posting a job without naming a price.

    An employer who does not know the going rate for a trade used to have
    to guess, because the amount was required. Choosing "Discuss payment
    terms" takes the amount fields away and the job carries no figure; the
    rate is agreed with the worker in the chat after hiring.
*/
void main() {
  Widget wrap(Widget screen) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
          ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
          ChangeNotifierProvider(create: (_) => JobProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
        ],
        child: MaterialApp(home: screen),
      );

  testWidgets('choosing to discuss the payment takes the amount away',
      (tester) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const PostJobScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // The amount is asked for by default.
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Payment period'), findsOneWidget);

    final choice = find.byWidgetPredicate(
      (w) => w is DropdownButton<String> && w.value == 'Set amount',
    );
    expect(choice, findsOneWidget);

    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discuss payment terms').last);
    await tester.pumpAndSettle();

    // No figure asked for, and the post says what will happen instead.
    expect(find.text('Amount'), findsNothing);
    expect(find.text('Payment period'), findsNothing);
    expect(
      find.textContaining('Payment terms: to be discussed'),
      findsOneWidget,
    );
  });
}
