import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/employer/screens/edit_employer_profile_screen.dart';
import 'package:kaya_app/features/employer/screens/setup_employer_profile_screen.dart';
import 'package:kaya_app/features/jobs/screens/post_job_screen.dart';
import 'package:kaya_app/features/profile/screens/my_employer_profile_screen.dart';
import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/features/credits/screens/wallet_screen.dart';
import 'package:kaya_app/features/employer/screens/manage_jobs_screen.dart';
import 'package:kaya_app/features/invitations/screens/my_invitations_screen.dart';
import 'package:kaya_app/features/jobs/screens/saved_jobs_screen.dart';
import 'package:kaya_app/features/jobs/screens/search_screen.dart';
import 'package:kaya_app/features/messaging/screens/messages_list_screen.dart';
import 'package:kaya_app/features/notifications/screens/notifications_screen.dart';
import 'package:kaya_app/features/profile/screens/my_worker_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/profile_screen.dart';
import 'package:kaya_app/features/profile/screens/settings_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/worker_browse_provider.dart';
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
    Which screens overflow on a small phone.

    Reported from real devices as "I get BOTTOM OVERFLOW everytime I use
    different phones and I cannot point them out" — which is the worst shape a
    bug report can have, not because it is vague but because it is true. There
    is no way to find these by reading: a layout that fits a 1080x2400 panel
    can break on a 720x1280 one, and the person holding the phone cannot tell
    you which widget did it.

    So this asks Flutter instead. RenderFlex reports an overflow through the
    error reporter rather than by throwing, so the frame still renders and a
    normal test passes right over it. Capturing that reporter turns each one
    into a named failure with a screen attached.

    Deliberately a small screen. 360x640 logical pixels is the low end of what
    is still common in the Philippines — an entry-level Android is exactly the
    device this app is for, and exactly the one nobody develops on.
*/
void main() {
  /*
      Two widths, because they fail differently.

      360 logical pixels is the ordinary entry-level Android and catches the
      vertical breaks — a header that cannot fit its own contents. 320 is the
      narrowest still in daily use here, and it catches the horizontal ones: a
      heading that shoves its own button off the right edge, a card sized in
      round numbers that no longer fits between the margins. Both of the bugs
      found in the home carousels only appeared at 320.
  */
  const widths = <double>[360, 320];

  /// Collects overflow complaints for one screen.
  ///
  /// Flutter routes these through FlutterError.onError rather than throwing,
  /// so without swapping the handler the test never hears about them.
  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget screen, {
    double textScale = 1.0,
    double width = 360,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        // "A RenderFlex overflowed by 43 pixels on the bottom." — the number
        // and the edge are the useful part.
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
          // Larger text is the other half of this: Android allows it, the app
          // clamps at 1.3, and a layout that only fits at 1.0 breaks for
          // anybody who has ever turned the setting up.
          //
          // Built from the view rather than from scratch, so the screen size
          // is the one set above and not zero.
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  /*
      Each screen is checked twice: at normal text and at the largest size the
      app permits. The second pass is where most of these live, because a card
      sized for two lines of text gets three and has nowhere to put the third.
  */
  Widget wrap(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => CreditsProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
      ],
      child: MaterialApp(home: screen),
    );
  }

  final screens = <String, Widget Function()>{
    'my worker profile': () => wrap(const MyWorkerProfileScreen()),
    'my employer profile': () => wrap(const MyEmployerProfileScreen()),
    'edit employer profile': () => wrap(const EditEmployerProfileScreen()),
    'setup employer profile': () => wrap(const SetupEmployerProfileScreen()),
    'post job': () => wrap(const PostJobScreen()),
    'profile': () => wrap(const ProfileScreen()),
    'settings': () => wrap(const SettingsScreen()),
    'wallet': () => wrap(const WalletScreen()),
    'messages': () => wrap(const MessagesListScreen()),
    'notifications': () => wrap(const NotificationsScreen()),
    'applications': () => wrap(const ApplicationsScreen()),
    'saved jobs': () => wrap(const SavedJobsScreen()),
    'my invitations': () => wrap(const MyInvitationsScreen()),
    'manage jobs': () => wrap(const ManageJobsScreen()),
    'search': () => wrap(const SearchScreen()),
  };

  for (final entry in screens.entries) {
    for (final width in widths) {
      for (final scale in <double>[1.0, 1.3]) {
        testWidgets(
            '${entry.key} fits a ${width.toInt()}px phone at text scale $scale',
            (tester) async {
          final complaints = await overflowsIn(
            tester,
            entry.value(),
            textScale: scale,
            width: width,
          );

          expect(
            complaints,
            isEmpty,
            reason: 'On a ${width.toInt()}px phone at text scale $scale, '
                '${entry.key} overflowed:\n  ${complaints.join('\n  ')}',
          );
        });
      }
    }
  }
}
