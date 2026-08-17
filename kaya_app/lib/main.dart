import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/app_mode_provider.dart';
import 'providers/worker_profile_provider.dart';
import 'providers/employer_profile_provider.dart';
import 'providers/job_provider.dart';
import 'providers/unified_home_provider.dart';
import 'providers/application_provider.dart';
import 'providers/invitation_provider.dart';
import 'providers/messaging_provider.dart';
import 'providers/job_tracking_provider.dart';
import 'providers/review_provider.dart';
import 'providers/location_provider.dart';
import 'providers/worker_browse_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_view_provider.dart';
import 'providers/verification_provider.dart';
import 'data/services/api_client.dart';

void main() {
  runApp(const KayaApp());
}

class KayaApp extends StatelessWidget {
  const KayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Active Worker/Employer mode. Mirrors profile existence from auth and
        // re-derives which modes the user is allowed to be in.
        ChangeNotifierProxyProvider<AuthProvider, AppModeProvider>(
          create: (_) => AppModeProvider(),
          update: (_, auth, previous) {
            final provider = previous ?? AppModeProvider();
            provider.reconcile(
              hasWorker: auth.workerProfileExists,
              hasEmployer: auth.employerProfileExists,
            );
            return provider;
          },
        ),

        // WorkerProfileProvider depends on AuthProvider
        // Auto-loads profile when auth state changes
        ChangeNotifierProxyProvider<AuthProvider, WorkerProfileProvider>(
          create: (_) => WorkerProfileProvider(ApiClient()),
          update: (context, auth, previous) {
            final provider = previous ?? WorkerProfileProvider(ApiClient());

            // Auto-fetch profile when user logs in and has worker profile.
            // The hasFetchedOnce guard matters: update() runs on every
            // AuthProvider notification, so without it the profile refetched
            // continuously whenever isLoading happened to be false.
            if (auth.isLoggedIn &&
                auth.workerProfileExists &&
                !provider.hasFetchedOnce &&
                !provider.isLoading) {
              // Schedule fetch for next frame to avoid calling during build
              Future.microtask(() => provider.fetchProfile());
            }

            return provider;
          },
        ),
        
        // EmployerProfileProvider depends on AuthProvider
        // Auto-loads profile when auth state changes
        ChangeNotifierProxyProvider<AuthProvider, EmployerProfileProvider>(
          create: (_) => EmployerProfileProvider(),
          update: (context, auth, previous) {
            final provider = previous ?? EmployerProfileProvider();
            
            // Auto-fetch profile when user logs in and has employer profile
            if (auth.isLoggedIn && 
                auth.employerProfileExists && 
                !provider.hasFetchedOnce && 
                !provider.isLoading) {
              // Schedule fetch for next frame to avoid calling during build
              Future.microtask(() => provider.fetchProfile());
            }
            
            return provider;
          },
        ),
        
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => UnifiedHomeProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => JobTrackingProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
      ],
      child: Builder(
        builder: (context) {
          /*
              An expired session now ends the session.

              Until this was wired, a dead token left the app looking signed in
              while every authenticated request failed silently — most visibly
              in the location picker, where nothing appeared as you typed. The
              only fix anyone found was clearing app data.
          */
          ApiClient.onUnauthorized = () {
            final navigator = _navigatorKey.currentState;
            if (navigator == null) return;

            context.read<AuthProvider>().logout();
            navigator.pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
          };

          return MaterialApp(
            navigatorKey: _navigatorKey,
            /*
                Caps how far the system font scale can stretch this app's text.

                Testers reported overflow stripes on some phones and not others
                with the same build. Android lets the user set text as large as
                2.0x, and the layouts here use fixed-height cards and rows —
                at 1.8x a card sized for two lines gets four and overflows.
                Which phones show it depends on each owner's accessibility
                setting, which is exactly why it looked random.

                Clamped rather than ignored: 1.0 would override someone's
                accessibility choice entirely, which is worse than a layout
                bug. 1.3 is enough to help people who need larger text while
                staying inside what these layouts can actually hold. Removing
                the fixed heights is the real fix and is tracked in the design
                pass (D1); this stops the bleeding for the current build.
            */
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: child ?? const SizedBox.shrink(),
            ),
            // On Android this becomes the task description in the app switcher,
            // so it has to match the launcher label in AndroidManifest.xml. It
            // read "KAYA - Job Marketplace" while the icon said "KAYA", which
            // showed the app under two different names depending on where you
            // looked.
            title: 'KAYA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            initialRoute: AppRouter.welcome,
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}

/// Lets the API client send an expired session back to the login screen without
/// a BuildContext of its own.
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
