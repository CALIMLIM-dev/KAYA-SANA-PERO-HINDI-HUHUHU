import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/navigation/app_router.dart';
import 'package:kaya_app/core/widgets/notification_banner.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/data/services/local_alerts.dart';
import 'package:kaya_app/features/help/screens/support_chat_screen.dart';
import 'package:kaya_app/features/notifications/screens/notifications_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';

import 'support/render_harness.dart';

/*
    Notifications, end to end, through the app's real routes.

    Reported: tapping a notification opened the screen twice, so it took two
    backs to leave; signing out slid the login screen in twice; the list
    repeated itself. Each of those came from something these tests now
    drive the real way - AppRouter.generateRoute, the real banner host, the
    real ApiClient over a fake server - rather than a copy of the logic.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  String? storedToken;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    ApiClient.testAdapter = server;
    storedToken = 'current-token';
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final key = (call.arguments as Map?)?['key'];
        return call.method == 'read' && key == 'auth_token' ? storedToken : null;
      },
    );
  });

  tearDown(() {
    ApiClient.testAdapter = null;
    ApiClient.onUnauthorized = null;
    LocalAlerts.onTap = null;
  });

  Map<String, dynamic> row(
    int id,
    String type, {
    String title = 'KAYA',
    String? body,
    String? referenceType,
    int? referenceId,
    String audience = 'both',
    bool read = false,
  }) =>
      {
        'id': id,
        'type': type,
        'audience': audience,
        'title': title,
        'body': body,
        'reference_type': referenceType,
        'reference_id': referenceId,
        'is_read': read,
        'created_at': DateTime.now().toIso8601String(),
        'age': 'just now',
      };

  Widget app(NotificationProvider notifications, {Widget? home}) {
    final key = GlobalKey<NavigatorState>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationProvider>.value(value: notifications),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
      ],
      child: MaterialApp(
        navigatorKey: key,
        navigatorObservers: [AppRouter.observer],
        onGenerateRoute: AppRouter.generateRoute,
        builder: (context, child) =>
            NotificationBannerHost(navigatorKey: key, child: child!),
        home: home ??
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => AppRouter.push(context, AppRouter.notifications),
                    child: const Text('Open notifications'),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  test('every named screen carries its name', () {
    const names = [
      AppRouter.welcome, AppRouter.login, AppRouter.signup,
      AppRouter.forgotPassword, AppRouter.verifyResetCode,
      AppRouter.resetPassword, AppRouter.googlePassword, AppRouter.home,
      AppRouter.searchJobs, AppRouter.matchedWorkers, AppRouter.jobDetails,
      AppRouter.workerProfile, AppRouter.postJob, AppRouter.savedJobs,
      AppRouter.applications, AppRouter.active, AppRouter.messages,
      AppRouter.chat, AppRouter.notifications, AppRouter.wallet,
      AppRouter.walletHistory, AppRouter.reportResponse, AppRouter.profile,
      AppRouter.myWorkerProfile, AppRouter.setupWorkerProfile,
      AppRouter.myEmployerProfile, AppRouter.addSkills, AppRouter.faq,
      AppRouter.support, AppRouter.setupEmployerProfile, AppRouter.manageJobs,
      AppRouter.viewApplicants, AppRouter.employerProfile,
      AppRouter.pinLocation, '/leave-review', '/verification', '/settings',
      '/my-invitations', '/edit-job', '/edit-employer-profile',
    ];

    for (final name in names) {
      final route = AppRouter.generateRoute(RouteSettings(name: name));
      // Without its name, push() cannot tell the screen is already open.
      expect(route.settings.name, name, reason: name);
    }
  });

  test('signed-out screens are recognised by name', () {
    for (final name in [AppRouter.welcome, AppRouter.login, AppRouter.signup, AppRouter.forgotPassword]) {
      expect(AppRouter.isSignedOutRoute(name), isTrue, reason: name);
    }
    expect(AppRouter.isSignedOutRoute(AppRouter.home), isFalse);
    expect(AppRouter.isSignedOutRoute(null), isFalse);
  });

  testWidgets('a screen already on top is not opened a second time', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(app(NotificationProvider()));

    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();

    // A second request for the same screen, the way a notification for it
    // arrives while it is open.
    AppRouter.push(tester.element(find.byType(NotificationsScreen)), AppRouter.notifications);
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a warning opens its whole text where it was tapped, and no second list',
      (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    const full = 'Your post asked people to pay outside the app. This is a warning; '
        'a second one suspends the account for seven days. If you think this '
        'is wrong, reply through Help and Support.';
    server.notifications = [
      row(5, 'moderation.warning', title: 'A warning from KAYA', body: full),
    ];

    await tester.pumpWidget(app(NotificationProvider()));
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A warning from KAYA'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(sheet.data, full);
    expect(find.byType(NotificationsScreen, skipOffstage: false), findsOneWidget);
    expect(server.calls, contains('PATCH /notifications/5/read'));
  });

  testWidgets('a pop-up opens its screen once, and the same alert from the shade does not open it again',
      (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    // On screen: a pop-up, not the phone's shade.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final notifications = NotificationProvider();
    await tester.pumpWidget(app(
      notifications,
      home: const Scaffold(body: Center(child: Text('Home'))),
    ));
    await tester.pump();

    // The first poll learns the line; the second carries the news.
    notifications.absorbPolled(const []);
    final reply = row(9, 'support.replied', title: 'KAYA replied', body: 'There is an answer waiting.');
    notifications.absorbPolled([AppNotification.fromJson(reply)]);
    // One frame to start the slide, one to finish it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('KAYA replied'), findsOneWidget);
    await tester.tap(find.text('KAYA replied'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportChatScreen, skipOffstage: false), findsOneWidget);

    // The phone's own copy of the same notification, tapped as well.
    LocalAlerts.onTap!(reply);
    await tester.pumpAndSettle();
    expect(find.byType(SupportChatScreen, skipOffstage: false), findsOneWidget);
  });

  test('a refusal for a session that has already ended does not end the next one', () async {
    var ended = 0;
    ApiClient.onUnauthorized = () => ended++;
    server.refuseEverything = true;

    // Signed out: the request went with no token, and its refusal is about
    // nobody.
    storedToken = null;
    await expectLater(ApiClient().get('/jobs'), throwsA(anything));
    expect(ended, 0);

    // Signed in, and the server stops accepting this phone's token: that
    // one is real.
    storedToken = 'current-token';
    await expectLater(ApiClient().get('/jobs'), throwsA(anything));
    expect(ended, 1);
  });

  test('one thread is one notification, and reading the thread reads it', () {
    final notifications = NotificationProvider();
    AppNotification message(int id) => AppNotification.fromJson(row(
          id,
          'message.received',
          title: id == 10 ? 'New message' : '2 new messages',
          body: 'Ramon Aquino: Pasok na po?',
          referenceType: 'conversation',
          referenceId: 3,
        ));

    notifications.absorbPolled(const []);
    notifications.absorbPolled([message(10)]);
    // The server folded 10 into 11, so the next poll only has 11.
    notifications.absorbPolled([message(11)]);

    final thread = notifications.items.where((n) => n.referenceId == 3).toList();
    expect(thread, hasLength(1));
    expect(thread.single.title, '2 new messages');
    expect(notifications.unreadTotal, 1);

    notifications.markConversationRead(3);
    expect(notifications.unreadTotal, 0);
  });
}

/// The server, as far as these screens ask it anything.
class _FakeServer implements HttpClientAdapter {
  List<Map<String, dynamic>> notifications = const [];
  bool refuseEverything = false;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    calls.add('${options.method} $path');

    if (refuseEverything) {
      return _json(401, {'message': 'Unauthenticated.'});
    }
    if (options.method == 'GET' && path.endsWith('/notifications')) {
      return _json(200, {
        'success': true,
        'data': {'data': notifications},
      });
    }
    if (options.method == 'GET' && path.endsWith('/support')) {
      return _json(200, {
        'success': true,
        'data': {'messages': [], 'incremental': false},
      });
    }
    return _json(200, {'success': true, 'data': null});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}
