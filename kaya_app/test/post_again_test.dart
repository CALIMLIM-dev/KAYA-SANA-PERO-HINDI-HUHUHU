import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/applications/screens/active_screen.dart';
import 'package:kaya_app/features/employer/screens/manage_jobs_screen.dart';
import 'package:kaya_app/features/jobs/screens/post_job_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/employer_profile_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/profile_view_provider.dart';
import 'package:kaya_app/providers/verification_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    An ended post put up again: the same form, filled in, posted as a new one
    for the spots nobody filled. Its dates are the employer's to choose again.
*/
void main() {
  Map<String, dynamic> job({
    int id = 7,
    String status = 'expired',
    int needed = 5,
    int filled = 1,
    bool again = true,
    bool urgent = true,
  }) =>
      {
        'id': id,
        'title': 'Five painters for a twelve unit subdivision in Villasis, exterior only',
        'description': 'Two coats, exterior only.',
        'category': {'id': 3, 'name': 'Painting'},
        'skills': [
          {'id': 11, 'name': 'Exterior Painting'},
        ],
        'status': status,
        'is_live': false,
        'can_post_again': again,
        'is_urgent': urgent,
        'budget_min': '800.00',
        'budget_period': 'daily',
        'application_count': 9,
        'workers_needed': needed,
        'workers_filled': filled,
        'hire_count': filled,
        'hire': null,
        'location': 'Urdaneta City',
        'city': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'location_id': 42,
        'latitude': '15.9761',
        'longitude': '120.5711',
        'photo_urls': ['https://kayaadmin.ucucite.tech/storage/job_photos/a.jpg'],
        'created_at': '2026-11-01T08:00:00Z',
        'start_date': '2026-11-02',
        'end_date': '2026-11-09',
        'work_starts_on': '2026-11-05',
        'expires_at': '2026-11-09T23:59:59Z',
      };

  Widget wrap(Widget home, {JobProvider? jobs, double textScale = 1.0}) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
          ChangeNotifierProvider(create: (_) => EmployerProfileProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => ProfileViewProvider()),
          ChangeNotifierProvider<JobProvider>.value(value: jobs ?? JobProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
          ChangeNotifierProvider(
              create: (_) => AppModeProvider()..reconcile(hasWorker: false, hasEmployer: true)),
          ChangeNotifierProvider(create: (_) => ApplicationProvider()),
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
          ChangeNotifierProvider(create: (_) => MessagingProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      );

  Future<void> open(WidgetTester tester, Widget widget, {Size size = const Size(1080, 2400)}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = size.width == 1080 ? 3.0 : 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the form is filled in from the old post, as a new one', (tester) async {
    await open(tester, wrap(PostJobScreen(again: job())));

    expect(find.text('Post Again'), findsOneWidget);
    expect(find.text('Edit Job'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Post Job'), findsOneWidget);
    expect(find.text('Five painters for a twelve unit subdivision in Villasis, exterior only'), findsOneWidget);
    expect(find.text('Two coats, exterior only.'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('Painting'), findsWidgets);
    // Its own photo, with a way to replace it.
    expect(find.text('Replace'), findsOneWidget);
    // The old dates are gone: a date that passed cannot be posted.
    expect(find.textContaining('Nov 9'), findsNothing);
    expect(find.textContaining('November 9'), findsNothing);
  });

  testWidgets('it asks for the spots nobody filled', (tester) async {
    await open(tester, wrap(PostJobScreen(again: job(needed: 5, filled: 1))));
    expect(find.text('4 workers', skipOffstage: false), findsOneWidget);
  });

  testWidgets('with nobody hired it asks for as many again', (tester) async {
    await open(tester, wrap(PostJobScreen(again: job(needed: 3, filled: 0))));
    expect(find.text('3 workers', skipOffstage: false), findsOneWidget);
  });

  test('the post says which one it is posted again from, and sends no photo of its own', () async {
    final adapter = _RecordingAdapter();
    ApiClient.testAdapter = adapter;
    addTearDown(() => ApiClient.testAdapter = null);

    await JobProvider().createJob(
      title: 'Fence',
      description: 'x',
      categoryId: 3,
      location: 'Urdaneta City',
      locationId: 42,
      photos: const [],
      startDate: DateTime(2026, 11, 25),
      endDate: DateTime(2026, 11, 28),
      repostOf: 7,
    );

    final form = adapter.sent!;
    expect(form.fields.singleWhere((f) => f.key == 'repost_of').value, '7');
    expect(form.files, isEmpty);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('Post Again fits My Jobs and the Active card at ${width.toInt()}px, text scale $scale', (tester) async {
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
          // Ended, and one that was closed, which offers nothing.
          await open(
            tester,
            wrap(const ManageJobsScreen(),
                textScale: scale,
                jobs: JobProvider()
                  ..seedMyJobs([job(id: 1, filled: 0), job(id: 2, status: 'closed', again: false)])),
            size: Size(width * 2, 2600),
          );
          expect(find.textContaining('Five painters'), findsNWidgets(2), reason: 'The cards never rendered.');
          expect(find.text('Post Again'), findsOneWidget);

          // Its date came with four spots still empty.
          await open(
            tester,
            wrap(const ActiveScreen(),
                textScale: scale,
                jobs: JobProvider()..seedMyJobs([job(id: 3, status: 'in_progress')])),
            size: Size(width * 2, 2600),
          );
          expect(find.text('Hired Workers (1 of 5)'), findsOneWidget, reason: 'The card never rendered.');
          expect(find.text('Post Again'), findsOneWidget);
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  FormData? sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data is FormData) sent = options.data as FormData;

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'ok',
        'data': {'id': 8, 'status': 'open'},
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
