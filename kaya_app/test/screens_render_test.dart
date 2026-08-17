import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/features/employer/screens/edit_employer_profile_screen.dart';
import 'package:kaya_app/features/jobs/widgets/jobs_near_you_section.dart';
import 'package:kaya_app/features/jobs/screens/post_job_screen.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/features/employer/screens/setup_employer_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/my_employer_profile_screen.dart';
import 'package:kaya_app/features/profile/screens/my_worker_profile_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    Screenshots of the real screens, for design review.

    Not assertions — these produce PNGs to look at. Every screen here is one
    that has been described in review as inconsistent or cluttered, and until
    now that was being judged from source code, which is a bad way to judge
    whether a heading looks like a heading.

    Providers are constructed but never fetched. Their network calls sit pending
    under the test's fake clock, so what renders is the empty state — which is
    exactly what a real user sees for the first second on every cold open, and
    is itself worth looking at.

    Run: flutter test test/screens_render_test.dart --update-goldens
*/
void main() {
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
      ],
      child: MaterialApp(home: screen),
    );
  }

  testWidgets('edit employer profile', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(const EditEmployerProfileScreen()),
      name: 'edit_employer_profile',
    );
  });

  testWidgets('setup employer profile', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(const SetupEmployerProfileScreen()),
      name: 'setup_employer_profile',
    );
  });

  testWidgets('my employer profile', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(const MyEmployerProfileScreen()),
      name: 'my_employer_profile',
    );
  });

  testWidgets('my worker profile', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(const MyWorkerProfileScreen()),
      name: 'my_worker_profile',
    );
  });

  /*
      The home job carousel, with jobs in it.

      The four screens above render their empty state, which is useful but
      cannot show an overflow — nothing overflows when there is no content. The
      reported overflow on the home job widget only appears with a real job in
      the card, and the worst case is the one with everything on at once: a long
      title, an urgent badge, a match score, a distance and a schedule.

      Given a fixed-height card, that is where it breaks.
  */
  final jobs = [
    Job(
      id: 1,
      jobId: 1,
      title: 'Experienced Aircon Technician for Commercial Building',
      company: 'Northern Luzon Facilities Management Corporation',
      location: 'Brgy. Nancayasan, Urdaneta City, Pangasinan',
      salaryMin: 850,
      salaryMax: 1500,
      salaryPeriod: 'day',
      isUrgent: true,
      isNegotiable: true,
      distance: 3.4,
      matchScore: 92,
      applicantCount: 12,
      requiredSkills: const ['Aircon Repair', 'Electrical', 'Welding'],
      startDate: DateTime(2026, 8, 20),
      endDate: DateTime(2026, 8, 27),
      startTime: '8:00 AM',
    ),
    const Job(
      id: 2,
      jobId: 2,
      title: 'Yaya',
      company: 'Dela Cruz',
      location: 'Urdaneta City',
      salaryMin: 500,
      salaryPeriod: 'day',
    ),
  ];

  testWidgets('home job carousel', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(
        Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                JobsNearYouSection(jobs: jobs, userLocation: 'Urdaneta City'),
              ],
            ),
          ),
        ),
      ),
      name: 'home_job_carousel',
    );
  });

  /*
      The job posting form, scrolled to the schedule block.

      Reported as confusing, and it was written without ever being seen. The
      screen is long, so this scrolls down to the part under review rather than
      screenshotting the header four times.
  */
  testWidgets('post job schedule', (tester) async {
    await RenderHarness.capture(
      tester,
      wrap(const PostJobScreen()),
      name: 'post_job_schedule',
      scrollBy: 1500,
    );
  });
}
