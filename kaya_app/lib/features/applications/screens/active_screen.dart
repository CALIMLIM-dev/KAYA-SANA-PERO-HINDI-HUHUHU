import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/realtime_refresh.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import 'applications_screen.dart';

/*
    Every piece of active work, where See all on the home screen goes.

    Home shows the first three. This is the rest of the same list, drawn with
    the same cards, read through the same activeItems rule - so a card cannot
    say one thing here and another on home.
*/
class ActiveScreen extends StatefulWidget {
  const ActiveScreen({super.key});

  @override
  State<ActiveScreen> createState() => _ActiveScreenState();
}

class _ActiveScreenState extends State<ActiveScreen> with RealtimeRefresh {
  @override
  List<String> get refreshOn => const ['application.', 'job.'];

  @override
  void onRealtimeRefresh() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      bindRealtimeRefresh();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final appMode = context.read<AppModeProvider>();

    await Future.wait([
      if (appMode.hasWorkerProfile)
        context.read<ApplicationProvider>().fetchMyApplications(),
      if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final applications = context.watch<ApplicationProvider>();
    final jobs = context.watch<JobProvider>();
    final items =
        activeItems(context.watch<AppModeProvider>(), applications, jobs);

    final loading = applications.isLoading || jobs.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    const Center(
                      child: Text(
                        'Nothing running',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral600,
                        ),
                      ),
                    ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [for (final row in items) activeCard(row, _load)],
              ),
      ),
    );
  }
}
