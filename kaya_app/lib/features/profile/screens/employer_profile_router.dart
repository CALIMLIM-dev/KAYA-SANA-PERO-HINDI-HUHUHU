import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../employer/screens/setup_employer_profile_screen.dart';
import 'my_employer_profile_screen.dart';

/// Routes employer users to setup or their provider-backed profile.
class EmployerProfileRouter extends StatelessWidget {
  const EmployerProfileRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployerProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasFetchedOnce) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null && !provider.hasFetchedOnce) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage ?? 'Unknown error',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.neutral600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.fetchProfile(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (provider.profile == null) {
          return const SetupEmployerProfileScreen();
        }

        return const MyEmployerProfileScreen();
      },
    );
  }
}
