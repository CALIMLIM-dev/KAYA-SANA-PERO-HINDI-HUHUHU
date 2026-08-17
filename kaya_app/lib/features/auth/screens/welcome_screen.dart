import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/auth_provider.dart';

/// Modern Onboarding/Welcome Screen with Professional Design
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isChecking = true; // Add loading state

  /// Set once the startup check has been running long enough that a bare
  /// spinner stops reassuring anyone.
  bool _isSlow = false;

  /// The session is still valid but the server could not be reached. Distinct
  /// from being signed out, and it must not look the same.
  bool _startupFailed = false;

  Timer? _slowTimer;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.work_outline,
      title: 'Find Skilled Workers',
      description: 'Connect with verified professionals for plumbing, electrical, construction, and more.',
    ),
    OnboardingPage(
      icon: Icons.verified_user,
      title: 'Verified Profiles',
      description: 'All workers are verified with ratings and reviews from previous jobs.',
    ),
    OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: 'Direct Communication',
      description: 'Chat directly with workers to discuss job details and negotiate terms.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    if (mounted) setState(() => _startupFailed = false);

    // The request can take up to a minute on a bad connection. Say something
    // after a few seconds rather than showing a bare circle the whole time.
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _isSlow = true);
    });

    // First check if user is already logged in
    final token = await ApiClient.getToken();
    if (token != null && mounted) {
      // User is logged in, go to home
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final appMode = Provider.of<AppModeProvider>(context, listen: false);

      await auth.fetchMe();

      if (mounted && auth.user != null) {
        // Restore the persisted Worker/Employer mode before the home screen
        // builds, so it opens in the right mode instead of flashing the
        // default and switching.
        await appMode.restore();
        _slowTimer?.cancel();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      /*
          The session survived; the network did not.

          Dropping the user at the login screen here is what made a flaky
          connection look like being signed out. They still hold a valid token,
          so the right thing is to say the connection failed and let them try
          again.
      */
      if (auth.lastFetchWasNetworkError) {
        _slowTimer?.cancel();
        if (mounted) {
          setState(() {
            _startupFailed = true;
            _isSlow = false;
          });
        }
        return;
      }
    }
    
    _slowTimer?.cancel();

    // Check if user has seen onboarding
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (hasSeenOnboarding && mounted) {
      // User has seen onboarding, skip to login
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // Show onboarding
      setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /*
        The startup screen used to be a bare CircularProgressIndicator for as
        long as /me took — up to a minute on the 30s connect + 30s receive
        timeouts — and then, if it failed, the login screen. No text, no retry,
        no explanation. That is what "the loading just freezes" was.
    */
    if (_startupFailed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.neutral300),
                const SizedBox(height: 16),
                Text(
                  "Can't reach KAYA",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Says what is true: they are still signed in.
                  'Check your connection and try again. You are still signed in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.neutral500),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _checkOnboardingStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text('Sign in with a different account',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              // Only after it has been slow enough to worry about. Showing this
              // immediately would make a fast start look like a problem.
              if (_isSlow) ...[
                const SizedBox(height: 20),
                Text(
                  'Still connecting…',
                  style: TextStyle(fontSize: 13.5, color: AppColors.neutral500),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _navigateToRoleSelection(),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.neutral600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            
            // Page view with onboarding content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_pages[index]);
                },
              ),
            ),
            
            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildDot(index == _currentPage),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _navigateToRoleSelection();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.neutral300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _navigateToRoleSelection() async {
    // Mark onboarding as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
