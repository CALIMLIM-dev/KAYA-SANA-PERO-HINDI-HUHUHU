import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/employer/screens/manage_jobs_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    A job for several people, on the employer's job cards.

    The crew line and the Roster button only draw when a job is for more
    than one person, so a card rendered from a default job never shows
    them and cannot overflow. These seed a five-person job, open with two
    hired and in progress with all five, at every width and text scale.
*/
void main() {
  Map<String, dynamic> job({
    required int id,
    required String status,
    required int needed,
    required int filled,
  }) =>
      {
        'id': id,
        'title': 'Five painters for a twelve unit subdivision in Villasis, exterior only',
        'status': status,
        'category': {'name': 'Painting'},
        'city': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'budget_min': 800,
        'budget_max': 1000,
        'budget_period': 'daily',
        'application_count': 9,
        'pending_application_count': 4,
        'workers_needed': needed,
        'workers_filled': filled,
        'hire_count': filled,
        'hire': null,
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'start_date': DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10),
        'end_date': DateTime.now().add(const Duration(days: 12)).toIso8601String().substring(0, 10),
        'expires_at': DateTime.now().add(const Duration(days: 12)).toIso8601String(),
      };

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required double textScale,
    required double width,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        complaints.add(text.split('\n').first.trim());
        return;
      }
      previous?.call(details);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);

      tester.view.physicalSize = Size(width * 2, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final jobs = JobProvider()
        ..seedMyJobs([
          job(id: 1, status: 'open', needed: 5, filled: 2),
          job(id: 2, status: 'in_progress', needed: 5, filled: 5),
        ]);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider<JobProvider>.value(value: jobs),
              ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
              ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
              ChangeNotifierProvider(create: (_) => CreditsProvider()),
              ChangeNotifierProvider(create: (_) => AppModeProvider()),
              ChangeNotifierProvider(create: (_) => ApplicationProvider()),
              ChangeNotifierProvider(create: (_) => InvitationProvider()),
              ChangeNotifierProvider(create: (_) => MessagingProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ],
            child: const MaterialApp(home: ManageJobsScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2 of 5 hired'), findsOneWidget,
          reason: 'The crew line never rendered, so nothing was checked.');
      expect(find.textContaining('Roster'), findsWidgets,
          reason: 'The roster button never rendered.');

      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 120));
      }
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets(
        'crew job cards fit ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(tester, textScale: scale, width: width);
          expect(complaints, isEmpty,
              reason: 'Crew cards overflowed at ${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}');
        },
      );
    }
  }
}
