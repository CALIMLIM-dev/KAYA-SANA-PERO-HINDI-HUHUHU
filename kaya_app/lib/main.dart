import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/worker_profile_provider.dart';
import 'providers/employer_profile_provider.dart';
import 'providers/job_provider.dart';
import 'providers/unified_home_provider.dart';
import 'providers/application_provider.dart';
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
        ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => UnifiedHomeProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ChangeNotifierProvider(create: (_) => VerificationProvider()),
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
