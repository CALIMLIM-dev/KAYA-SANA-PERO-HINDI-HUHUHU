import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_mode_provider.dart';
import '../../providers/application_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/worker_browse_provider.dart';
import '../../providers/worker_profile_provider.dart';
import 'widgets/home_carousel.dart';

/*
    Home, loaded while the icon builds.

    Home asked for its lists only once it was on screen, so it opened with
    sections still empty and filled them in a moment later - the carousel,
    the jobs, the categories each arriving on its own. The opening animation
    is already a second or two the person spends waiting, so the same
    requests go out during it and home opens with them answered.

    Capped, so a slow connection holds the opening for a few seconds at most;
    whatever has not arrived by then, home asks for itself as before.
*/
class HomeWarmup {
  HomeWarmup._();

  static const limit = Duration(seconds: 5);

  static Future<void> run(BuildContext context) async {
    // Everything read before the first await, while the context is live.
    final mode = context.read<AppModeProvider>();
    final jobs = context.read<JobProvider>();
    final browse = context.read<WorkerBrowseProvider>();
    final applications = context.read<ApplicationProvider>();
    final taxonomy = context.read<WorkerProfileProvider>();

    // The same town home bounds its worker list by (see _adoptKnownPlace).
    final known = context.read<AuthProvider>().user?['known_location'] as Map<String, dynamic>?;
    final city = (known?['city'] as Map<String, dynamic>?) ?? known;
    final cityId = (city?['location_id'] as num?)?.toInt();

    final employerOnly = mode.hasEmployerProfile && !mode.hasWorkerProfile;
    final workerOnly = mode.hasWorkerProfile && !mode.hasEmployerProfile;

    try {
      await Future.wait([
        if (!employerOnly) jobs.fetchPublicJobs(nearestFirst: true),
        if (!workerOnly) browse.fetchWorkers(locationId: cityId),
        if (!workerOnly) browse.fetchMostHired(locationId: cityId),
        if (mode.hasEmployerProfile) jobs.fetchMyJobs(),
        if (mode.hasWorkerProfile) applications.fetchMyApplications(),
        taxonomy.fetchCategories(),
        HomeCarousel.prefetch(HomeCarousel.sideFor(mode)),
      ]).timeout(limit);
    } catch (_) {
      // Late or failed: home asks again on its own.
    }
  }
}
