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
import 'providers/review_provider.dart';
import 'providers/location_provider.dart';
import 'providers/worker_browse_provider.dart';
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
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => WorkerBrowseProvider()),
      ],
      child: MaterialApp(
        title: 'KAYA - Job Marketplace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.welcome,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
