import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/applications/screens/active_screen.dart';
import 'package:kaya_app/features/applications/screens/applications_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';
import 'package:kaya_app/providers/job_provider.dart';

import 'support/render_harness.dart';

/*
    Working together again starts from History.

    There used to be a separate "worked with before" screen behind an icon in
    the My Jobs app bar. It listed the same people whose finished jobs are in
    History, so the job somebody remembered and the person they wanted to hire
    again were in two different places. Both sides now act from the finished
    job itself.

    The worker's half matters more than it looks: the conversation is hidden
    once a job completes, so without this a worker who did well for somebody
    had no way back to them at all.
*/
void main() {
  /*
      Asking for work again is a request now, not a page push, so the tap
      has to reach something. This records where it went and answers
      successfully, which is all these tests need.
  */
  late _RecordingAdapter adapter;

  setUp(() {
    adapter = _RecordingAdapter();
    ApiClient.testAdapter = adapter;
  });

  tearDown(() {
    ApiClient.testAdapter = null;
  });

  Map<String, dynamic> finishedApplication({int openJobs = 2}) => {
        'id': 91,
        'status': 'completed',
        // Whether asking them again leads anywhere. The card says so
        // rather than opening a profile with nothing on it.
        'employer_open_jobs': openJobs,
        'conversation_id': 12,
        'worker_completed_at': '2026-09-01T08:00:00Z',
        'employer_completed_at': '2026-09-01T09:00:00Z',
        'i_reviewed_them': true,
        'they_reviewed_me': true,
        'job': {
          'id': 5,
          'title': 'Repainting of a three bedroom bungalow',
          'category': {'id': 3, 'name': 'Painting'},
          'city': 'Urdaneta City, Pangasinan',
          'budget_min': 900,
          'budget_max': 1200,
          'status': 'completed',
          'employer': {
            'id': 9,
            'name': 'Santiago Construction and General Services',
            'is_verified': true,
          },
        },
      };

  Map<String, dynamic> liveApplication() => {
        ...finishedApplication(),
        'id': 92,
        'status': 'accepted',
        'i_reviewed_them': false,
        'they_reviewed_me': false,
        'job': {
          ...finishedApplication()['job'] as Map<String, dynamic>,
          'status': 'in_progress',
        },
      };

  Widget screen(List<Map<String, dynamic>> applications, {bool active = false}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppModeProvider>.value(
            value: AppModeProvider()..reconcile(hasWorker: true, hasEmployer: false),
          ),
          ChangeNotifierProvider<ApplicationProvider>.value(
            value: ApplicationProvider()..seedApplications(applications),
          ),
          ChangeNotifierProvider<InvitationProvider>.value(
            value: InvitationProvider()..seedInvitations([]),
          ),
          ChangeNotifierProvider<JobProvider>.value(value: JobProvider()..seedMyJobs([])),
        ],
        child: MaterialApp(
            home: active ? const ActiveScreen() : const ApplicationsScreen()),
      );

  Future<void> render(WidgetTester tester, Widget widget) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// My Activity is History now; live work moved to the Active screen.
  Future<void> openHistory(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a finished job offers the way back to that employer',
      (tester) async {
    await render(tester, screen([finishedApplication()]));
    await openHistory(tester);

    expect(find.text('Ask for Work Again'), findsWidgets,
        reason: 'the thread is hidden once the job is done, so History is the '
            'only route back to somebody you worked well for');
    expect(find.text('Message'), findsNothing,
        reason: 'there is no thread left to open on a finished job');
  });

  testWidgets('the tap asks the employer rather than opening their page',
      (tester) async {
    /*
        This used to assert a toast saying the employer had nothing open, and
        before that the tap pushed their profile. Neither was asking anybody
        anything, which is what the button says it does - and it could not
        message them either, because finishing a job archives the pair's
        thread on purpose.

        So the tap now sends one request, and having nothing open no longer
        stops it: an employer with nothing posted today is exactly who should
        hear that somebody they rated well is free again.
    */
    await render(tester, screen([finishedApplication(openJobs: 0)]));
    await openHistory(tester);

    // The label does not change. A button that renames itself to say no
    // reads as broken, so it keeps its name and answers when pressed.
    expect(find.text('Ask for Work Again'), findsWidgets);

    await tester.tap(find.text('Ask for Work Again').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      adapter.asked,
      contains('/employers/9/work-again'),
      reason: 'the tap has to reach the employer, not a page',
    );

    // Let the toast time out, or it leaves a pending timer behind it.
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets('live work still offers the thread, not the detour',
      (tester) async {
    await render(tester, screen([liveApplication()], active: true));

    expect(find.text('Message'), findsWidgets);
    expect(find.text('Ask for Work Again'), findsNothing);
  });
}

/*
    Records the paths asked for and answers every one successfully.

    ApiClient reads a token from secure storage on each request, so these
    tests also stub the platform channels through RenderHarness.
*/
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> asked = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.path);

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}