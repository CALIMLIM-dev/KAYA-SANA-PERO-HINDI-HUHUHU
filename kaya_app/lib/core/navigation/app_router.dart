import 'package:flutter/material.dart';
import '../../data/models/job_model.dart';
import '../../data/models/worker_profile_model.dart';

// Auth Screens
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';

// Main Navigation
import 'main_navigation.dart';

// Job Related Screens
import '../../features/jobs/screens/job_details_screen.dart';
import '../../features/jobs/screens/post_job_screen.dart';
import '../../features/jobs/screens/search_screen.dart';
import '../../features/jobs/screens/saved_jobs_screen.dart';

// Worker Profile Screens
import '../../features/worker_profile/screens/worker_profile_screen.dart';
import '../../features/worker_profile/screens/edit_worker_profile_screen.dart';

// Application Screens
import '../../features/applications/screens/applications_screen.dart';

// Messaging Screens
import '../../features/messaging/screens/messages_list_screen.dart';
import '../../features/messaging/screens/conversations_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';

// Notification Screens
import '../../features/notifications/screens/notifications_screen.dart';

// Profile Screens
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/my_worker_profile_screen.dart';
import '../../features/profile/screens/my_employer_profile_screen.dart';
import '../../features/profile/screens/add_name_screen.dart';
import '../../features/profile/screens/add_location_screen.dart';
import '../../features/profile/screens/add_personal_details_screen.dart';
import '../../features/profile/screens/add_skills_screen.dart';
import '../../features/profile/screens/add_experience_screen.dart';
import '../../features/profile/screens/upload_resume_screen.dart';
import '../../features/profile/screens/add_photo_screen.dart';
import '../../features/profile/screens/add_certifications_screen.dart';
import '../../features/profile/screens/add_licenses_screen.dart';

// Employer Screens
import '../../features/employer/screens/setup_employer_profile_screen.dart';
import '../../features/employer/screens/add_employer_details_screen.dart';
import '../../features/employer/screens/add_employer_contact_screen.dart';
import '../../features/employer/screens/add_employer_location_screen.dart';
import '../../features/employer/screens/add_employer_about_screen.dart';
import '../../features/employer/screens/manage_jobs_screen.dart';
import '../../features/employer/screens/employer_profile_screen.dart';
import '../../features/applications/screens/view_applicants_screen.dart';
import '../../features/applications/screens/applicant_review_screen.dart';
import '../../features/reviews/screens/leave_review_screen.dart';
import '../../features/profile/screens/verification_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/invitations/screens/my_invitations_screen.dart';
import '../../features/jobs/screens/edit_job_screen.dart';
import '../../features/employer/screens/edit_employer_profile_screen.dart';

// Help Screens
import '../../features/help/screens/faq_screen.dart';

/// Centralized app router for navigation management
class AppRouter {
  static const String welcome = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String jobDetails = '/job-details';
  static const String workerProfile = '/worker-profile';
  static const String postJob = '/post-job';
  static const String searchJobs = '/search';
  static const String savedJobs = '/saved-jobs';
  static const String applications = '/applications';
  static const String messages = '/messages';
  static const String chat = '/chat';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editWorkerProfile = '/edit-worker-profile';
  static const String myWorkerProfile = '/my-worker-profile';
  static const String myEmployerProfile = '/my-employer-profile';
  static const String addName = '/add-name';
  static const String addLocation = '/add-location';
  static const String addPersonalDetails = '/add-personal-details';
  static const String addSkills = '/add-skills';
  static const String addExperience = '/add-experience';
  static const String uploadResume = '/upload-resume';
  static const String addPhoto = '/add-photo';
  static const String addCertifications = '/add-certifications';
  static const String addLicenses = '/add-licenses';
  static const String faq = '/faq';
  static const String setupEmployerProfile = '/setup-employer-profile';
  static const String addEmployerDetails = '/add-employer-details';
  static const String addEmployerContact = '/add-employer-contact';
  static const String addEmployerLocation = '/add-employer-location';
  static const String addEmployerAbout = '/add-employer-about';
  static const String manageJobs = '/manage-jobs';
  static const String viewApplicants = '/view-applicants';
  static const String employerProfile = '/employer-profile';

  /// Generate routes for the app
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      
      case profileSetup:
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      
      case home:
        return MaterialPageRoute(builder: (_) => const MainNavigation());
      
      case jobDetails:
        // For now, just navigate to job details without parameters
        // TODO: Update JobDetailsScreen to accept Job parameter
        return MaterialPageRoute(
          builder: (_) => const JobDetailsScreen(),
        );
      
      case workerProfile:
        // For now, just navigate to worker profile without parameters  
        // TODO: Update WorkerProfileScreen to accept WorkerProfile parameter
        return MaterialPageRoute(
          builder: (_) => const WorkerProfileScreen(),
        );
      
      case postJob:
        return MaterialPageRoute(builder: (_) => const PostJobScreen());
      
      case searchJobs:
        final initialQuery = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => SearchScreen(initialQuery: initialQuery),
        );
      
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
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case editWorkerProfile:
        return MaterialPageRoute(builder: (_) => const EditWorkerProfileScreen());
      
      case myWorkerProfile:
        return MaterialPageRoute(builder: (_) => const MyWorkerProfileScreen());
      
      case myEmployerProfile:
        return MaterialPageRoute(builder: (_) => const MyEmployerProfileScreen());
      
      case addName:
        return MaterialPageRoute(builder: (_) => const AddNameScreen());
      
      case addLocation:
        return MaterialPageRoute(builder: (_) => const AddLocationScreen());
      
      case addPersonalDetails:
        return MaterialPageRoute(builder: (_) => const AddPersonalDetailsScreen());
      
      case addSkills:
        return MaterialPageRoute(builder: (_) => const AddSkillsScreen());
      
      case addExperience:
        return MaterialPageRoute(builder: (_) => const AddExperienceScreen());
      
      case uploadResume:
        return MaterialPageRoute(builder: (_) => const UploadResumeScreen());
      
      case addPhoto:
        return MaterialPageRoute(builder: (_) => const AddPhotoScreen());
      
      case addCertifications:
        return MaterialPageRoute(builder: (_) => const AddCertificationsScreen());
      
      case addLicenses:
        return MaterialPageRoute(builder: (_) => const AddLicensesScreen());
      
      case faq:
        return MaterialPageRoute(builder: (_) => const FAQScreen());
      
      case setupEmployerProfile:
        return MaterialPageRoute(builder: (_) => const SetupEmployerProfileScreen());
      
      case addEmployerDetails:
        final initialName = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => AddEmployerDetailsScreen(initialName: initialName),
        );
      
      case addEmployerContact:
        return MaterialPageRoute(builder: (_) => const AddEmployerContactScreen());
      
      case addEmployerLocation:
        return MaterialPageRoute(builder: (_) => const AddEmployerLocationScreen());
      
      case addEmployerAbout:
        return MaterialPageRoute(builder: (_) => const AddEmployerAboutScreen());
      
      case manageJobs:
        return MaterialPageRoute(builder: (_) => const ManageJobsScreen());
      
      case viewApplicants:
        return MaterialPageRoute(builder: (_) => const ViewApplicantsScreen());
      
      case '/applicant-review':
        return MaterialPageRoute(
          builder: (_) => const ApplicantReviewScreen(),
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
        return MaterialPageRoute(builder: (_) => const EmployerProfileScreen());
      
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

  /// Navigate to job details screen
  static void toJobDetails(BuildContext context, Job job) {
    Navigator.pushNamed(context, jobDetails, arguments: job);
  }

  /// Navigate to worker profile screen
  static void toWorkerProfile(BuildContext context, WorkerProfile worker) {
    Navigator.pushNamed(context, workerProfile, arguments: worker);
  }

  /// Navigate to post job screen
  static void toPostJob(BuildContext context) {
    Navigator.pushNamed(context, postJob);
  }

  /// Navigate to search jobs screen
  static void toSearchJobs(BuildContext context, {String? query}) {
    Navigator.pushNamed(context, searchJobs, arguments: query);
  }

  /// Navigate to saved jobs screen
  static void toSavedJobs(BuildContext context) {
    Navigator.pushNamed(context, savedJobs);
  }

  /// Navigate to applications screen
  static void toApplications(BuildContext context) {
    Navigator.pushNamed(context, applications);
  }

  /// Navigate to messages screen
  static void toMessages(BuildContext context) {
    Navigator.pushNamed(context, messages);
  }

  /// Navigate to chat screen
  static void toChat(BuildContext context, {
    required int workerId,
    required String workerName,
    String? workerImageUrl,
    int? jobId,
  }) {
    Navigator.pushNamed(
      context,
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
    Navigator.pushNamed(context, notifications);
  }

  /// Navigate to profile screen
  static void toProfile(BuildContext context) {
    Navigator.pushNamed(context, profile);
  }

  /// Navigate to edit worker profile screen
  static void toEditWorkerProfile(BuildContext context) {
    Navigator.pushNamed(context, editWorkerProfile);
  }

  /// Navigate to my worker profile screen
  static void toMyWorkerProfile(BuildContext context) {
    Navigator.pushNamed(context, myWorkerProfile);
  }

  /// Navigate to my employer profile screen
  static void toMyEmployerProfile(BuildContext context) {
    Navigator.pushNamed(context, myEmployerProfile);
  }

  /// Navigate to FAQ screen
  static void toFAQ(BuildContext context) {
    Navigator.pushNamed(context, faq);
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