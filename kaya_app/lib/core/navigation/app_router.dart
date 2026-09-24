import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../data/models/job_model.dart';
import '../../data/models/worker_profile_model.dart';

// Auth Screens
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/verify_reset_code_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/google_password_screen.dart';

// Main Navigation
import 'main_navigation.dart';

// Job Related Screens
import '../../features/jobs/screens/job_details_screen.dart';
import '../../features/jobs/screens/search_screen.dart';
import '../../features/jobs/screens/post_job_screen.dart';
import '../../features/jobs/screens/saved_jobs_screen.dart';

// Worker Profile Screens
import '../../features/worker_profile/screens/worker_profile_screen.dart';

// Application Screens
import '../../features/applications/screens/applications_screen.dart';

// Messaging Screens
import '../../features/messaging/screens/messages_list_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';

// Notification Screens
import '../../features/credits/screens/wallet_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';

// Profile Screens
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/worker_profile_router.dart';
import '../../features/profile/screens/employer_profile_router.dart';
import '../../features/profile/screens/add_skills_screen.dart';

// Employer Screens
import '../../features/employer/screens/setup_employer_profile_screen.dart';
import '../../features/employer/screens/manage_jobs_screen.dart';
import '../../features/employer/screens/employer_profile_screen.dart';
import '../../features/applications/screens/view_applicants_screen.dart';
import '../../features/reviews/screens/leave_review_screen.dart';
import '../../features/profile/screens/verification_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/invitations/screens/my_invitations_screen.dart';
import '../../features/jobs/screens/edit_job_screen.dart';
import '../../features/employer/screens/edit_employer_profile_screen.dart';

// Help Screens
import '../../features/help/screens/faq_screen.dart';

// Location
import '../../features/location/screens/pin_location_screen.dart';

/// Centralized app router for navigation management
class AppRouter {
  static const String welcome = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String verifyResetCode = '/verify-reset-code';
  static const String resetPassword = '/reset-password';
  static const String googlePassword = '/google-password';
  static const String home = '/home';
  static const String searchJobs = '/search';
  static const String jobDetails = '/job-details';
  static const String workerProfile = '/worker-profile';
  static const String postJob = '/post-job';
  static const String savedJobs = '/saved-jobs';
  static const String applications = '/applications';
  static const String messages = '/messages';
  static const String chat = '/chat';
  static const String notifications = '/notifications';
  static const String wallet = '/wallet';
  static const String profile = '/profile';
  static const String myWorkerProfile = '/my-worker-profile';
  static const String setupWorkerProfile = '/setup-worker-profile';
  static const String myEmployerProfile = '/my-employer-profile';
  static const String addSkills = '/add-skills';
  static const String faq = '/faq';
  static const String setupEmployerProfile = '/setup-employer-profile';
  static const String manageJobs = '/manage-jobs';
  static const String viewApplicants = '/view-applicants';
  static const String employerProfile = '/employer-profile';
  static const String pinLocation = '/pin-location';

  /*
      What is on the navigator right now.

      Registered on the MaterialApp. push() below asks it whether the route
      it is about to open is already the one on top, which is how a second
      tap on the same card, a notification for the job already open, or a
      chat opening the job that opened the chat stop stacking copies of
      the same screen that all have to be backed out of one by one.
  */
  static final RouteStack observer = RouteStack();

  /// Pushes a named route unless that exact route, with the same
  /// arguments, is already on top. Every screen goes through this.
  static Future<T?> push<T extends Object?>(BuildContext context, String route,
      {Object? arguments}) {
    final top = observer.top;
    if (top != null &&
        top.settings.name == route &&
        const DeepCollectionEquality().equals(top.settings.arguments, arguments)) {
      return Future<T?>.value(null);
    }

    return Navigator.pushNamed<T>(context, route, arguments: arguments);
  }

  /// Generate routes for the app
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      
      
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      
      case verifyResetCode:
        return MaterialPageRoute(
          builder: (_) => const VerifyResetCodeScreen(),
          settings: settings,
        );
      
      case resetPassword:
        return MaterialPageRoute(
          builder: (_) => const ResetPasswordScreen(),
          settings: settings,
        );
      
      case googlePassword:
        return MaterialPageRoute(
          builder: (_) => const GooglePasswordScreen(),
          settings: settings,
        );
      
      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigation());

      case searchJobs:
        /*
            A string or a map, because both call it.

            Older callers pass the search term alone. The home category strip
            passes a category id and which side to search, so tapping a
            category filters on the category instead of typing its name into
            the box.
        */
        final args = settings.arguments;
        final query = args is String ? args : (args as Map?)?['query'] as String?;
        final categoryId = args is Map ? args['categoryId'] as int? : null;
        final searchType = args is Map ? args['searchType'] as String? : null;
        return MaterialPageRoute(
          builder: (_) => SearchScreen(
            initialQuery: query,
            initialCategoryId: categoryId,
            initialType: searchType,
          ),
        );
      
      case jobDetails:
        return MaterialPageRoute(
          builder: (_) => const JobDetailsScreen(),
          settings: settings,
        );

      case workerProfile:
        return MaterialPageRoute(
          builder: (_) => const WorkerProfileScreen(),
          settings: settings,
        );
      
      case postJob:
        return MaterialPageRoute(builder: (_) => const PostJobScreen());
      

      case savedJobs:
        return MaterialPageRoute(builder: (_) => const SavedJobsScreen());
      
      case applications:
        return MaterialPageRoute(builder: (_) => const ApplicationsScreen());
      
      case messages:
        return MaterialPageRoute(builder: (_) => const MessagesListScreen());
      
      case chat:
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(),
          settings: settings,
        );
      
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case wallet:
        return MaterialPageRoute(builder: (_) => const WalletScreen());

      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      

      case myWorkerProfile:
      case setupWorkerProfile:
        return MaterialPageRoute(builder: (_) => const WorkerProfileRouter());

      case myEmployerProfile:
        return MaterialPageRoute(builder: (_) => const EmployerProfileRouter());
      

      case addSkills:
        final initSkills = (settings.arguments as List<dynamic>?)?.cast<String>() ?? [];
        return MaterialPageRoute(builder: (_) => AddSkillsScreen(initialSkills: initSkills));
      

      case faq:
        return MaterialPageRoute(builder: (_) => const FAQScreen());
      
      case setupEmployerProfile:
        return MaterialPageRoute(builder: (_) => const SetupEmployerProfileScreen());
      

      case manageJobs:
        return MaterialPageRoute(builder: (_) => const ManageJobsScreen());
      
      case viewApplicants:
        return MaterialPageRoute(
          builder: (_) => const ViewApplicantsScreen(),
          settings: settings,
        );
      

      case '/leave-review':
        return MaterialPageRoute(
          builder: (_) => const LeaveReviewScreen(),
          settings: settings,
        );

      case '/verification':
        return MaterialPageRoute(
          builder: (_) => const VerificationScreen(),
          settings: settings,
        );

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/my-invitations':
        return MaterialPageRoute(builder: (_) => const MyInvitationsScreen());

      case '/edit-job':
        return MaterialPageRoute(
          builder: (_) => const EditJobScreen(),
          settings: settings,
        );

      case '/edit-employer-profile':
        return MaterialPageRoute(
          builder: (_) => const EditEmployerProfileScreen(),
          settings: settings,
        );
      
      case employerProfile:
        return MaterialPageRoute(
          builder: (_) => const EmployerProfileScreen(),
          settings: settings,
        );

      case pinLocation:
        return MaterialPageRoute(
          builder: (_) => const PinLocationScreen(),
          settings: settings,
        );
      
      default:
        return _errorRoute('Page not found: ${settings.name}');
    }
  }

  /// Error route for unknown or invalid routes
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, home, (route) => false),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to job details screen. Only the id is passed — the screen fetches
  /// the rest live via GET /jobs/{id}, so the details are never stale relative
  /// to whatever list the tap came from.
  static void toJobDetails(BuildContext context, Job job) {
    push(context, jobDetails, arguments: {'jobId': job.id});
  }

  /// Navigate to worker profile screen. Same reasoning as toJobDetails: only
  /// the id travels, the screen fetches the full profile itself.
  static void toWorkerProfile(BuildContext context, WorkerProfile worker) {
    push(context, workerProfile,
        arguments: {'workerId': worker.userId ?? worker.id});
  }

  /// Navigate to post job screen
  static void toPostJob(BuildContext context) {
    push(context, postJob);
  }

  /// Navigate to search jobs screen
  static void toSearchJobs(
    BuildContext context, {
    String? query,
    int? categoryId,
    String? searchType,
  }) {
    push(context,
      searchJobs,
      arguments: categoryId == null && searchType == null
          ? query
          : {
              'query': query,
              'categoryId': categoryId,
              'searchType': searchType,
            },
    );
  }

  /// Navigate to saved jobs screen
  static void toSavedJobs(BuildContext context) {
    push(context, savedJobs);
  }

  /// Navigate to applications screen
  static void toApplications(BuildContext context) {
    push(context, applications);
  }

  /// Open the inbox.
  ///
  /// Selects the shell's Messages tab rather than pushing the inbox over the
  /// top of it — pushing leaves the user on a screen with no bottom navigation
  /// and no obvious way back into the app.
  static void toMessages(BuildContext context) {
    MainNavigation.openMessages(context);
  }

  /// Navigate to chat screen
  static void toChat(BuildContext context, {
    required int workerId,
    required String workerName,
    String? workerImageUrl,
    int? jobId,
  }) {
    push(context,
      chat,
      arguments: {
        'workerId': workerId,
        'workerName': workerName,
        'workerImageUrl': workerImageUrl,
        'jobId': jobId,
      },
    );
  }

  /// Navigate to notifications screen
  static void toNotifications(BuildContext context) {
    push(context, notifications);
  }

  /// Navigate to profile screen
  static void toProfile(BuildContext context) {
    push(context, profile);
  }

  /// Navigate to my worker profile screen
  static void toMyWorkerProfile(BuildContext context) {
    push(context, myWorkerProfile);
  }

  /// Navigate to public employer profile (read-only view for workers)
  static void toEmployerProfile(BuildContext context) {
    push(context, employerProfile);
  }

  /// Navigate to my employer profile (NEW system - own profile management)
  static void toMyEmployerProfile(BuildContext context) {
    push(context, myEmployerProfile);
  }

  /// Navigate to FAQ screen
  static void toFAQ(BuildContext context) {
    push(context, faq);
  }

  /// Navigate to home screen and clear stack
  static void toHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, home, (route) => false);
  }

  /// Navigate to login screen and clear stack
  static void toLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, login, (route) => false);
  }

  /// Go back to previous screen
  static void back(BuildContext context) {
    Navigator.pop(context);
  }

  /// Check if we can go back
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}

/// Keeps the list of routes the root navigator currently holds.
class RouteStack extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];

  Route<dynamic>? get top => _routes.isEmpty ? null : _routes.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute != null) {
        _routes[i] = newRoute;
      } else {
        _routes.removeAt(i);
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
  }
}
