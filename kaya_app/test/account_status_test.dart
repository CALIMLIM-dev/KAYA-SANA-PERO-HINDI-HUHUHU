import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/moderation/screens/account_status_screen.dart';
import 'package:kaya_app/features/moderation/screens/report_response_screen.dart';
import 'package:kaya_app/features/notifications/notification_destination.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';

import 'support/render_harness.dart';

/*
    Fair moderation, as the person on the other end of it sees it.

    A strike arrives with its reasons and a way to appeal; a suspended
    account can still reach that page; a report about you shows the rule
    and your own content, never the person who filed it.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeServer();
    ApiClient.testAdapter = server;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'saved-token' : null,
    );
  });

  tearDown(() {
    ApiClient.testAdapter = null;
    ApiClient.sessionOverride = null;
  });

  // Phone width, tall enough that every card is laid out.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ],
        child: MaterialApp(home: home),
      );

  Map<String, dynamic> strike({bool canAppeal = true, Map<String, dynamic>? appeal}) => {
        'id': 4,
        'rule': 'Misleading job postings',
        'rule_description': 'Advertised work, pay, or conditions that did not match reality.',
        'action': 'restriction',
        'action_label': 'Restricted for 3 days',
        'finding': 'The post said 1500 a day and paid 800.',
        'content': {'kind': 'Job post', 'title': 'Paint a gate', 'text': '1500 for one day'},
        'issued_at': '2026-10-12T02:00:00Z',
        'ends_at': '2026-10-15T02:00:00Z',
        'expires_at': '2027-04-10T02:00:00Z',
        'counting': true,
        'can_appeal': canAppeal,
        'appeal_by': '2026-11-11T02:00:00Z',
        'appeal': appeal,
      };

  testWidgets('a strike shows its reasons and can be appealed', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    phone(tester);
    server.standing = {
      'standing': 'restricted',
      'restricted_until': '2026-10-15T02:00:00Z',
      'strikes_counting': 2,
      'strike_days': 180,
      'strikes': [strike()],
    };

    await tester.pumpWidget(app(const AccountStatusScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Restricted Until Oct 15, 2026'), findsOneWidget);
    expect(find.text('Misleading job postings'), findsOneWidget);
    expect(find.text('The post said 1500 a day and paid 800.'), findsOneWidget);
    expect(find.text('Paint a gate'), findsOneWidget);
    expect(find.textContaining('2 strikes counting'), findsOneWidget);

    await tester.tap(find.text('Request a Review'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(ElevatedButton, 'Send Request');
    expect(tester.widget<ElevatedButton>(send).onPressed, isNull, reason: 'too short to send');

    await tester.enterText(find.byType(TextField), 'The employer changed the price on the day, the chat shows it.');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(server.calls, contains('POST /account/strikes/4/appeal'));
    expect(server.lastBody?['appeal'], startsWith('The employer changed the price'));
    // Let the confirmation toast run out.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a decided appeal shows the decision instead of the button', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    phone(tester);
    server.standing = {
      'standing': 'good',
      'strikes_counting': 0,
      'strike_days': 180,
      'strikes': [
        strike(canAppeal: false, appeal: {
          'text': 'It was not me.',
          'status': 'overturned',
          'note': 'The chat shows the price was agreed.',
          'sent_at': '2026-10-13T02:00:00Z',
        })
      ],
    };

    await tester.pumpWidget(app(const AccountStatusScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Good Standing'), findsOneWidget);
    expect(find.textContaining('Accepted. The chat shows the price was agreed.'), findsOneWidget);
    expect(find.text('Request a Review'), findsNothing);
  });

  testWidgets('a suspended sign-in reaches its status on the short session, with support and sign out',
      (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    phone(tester);
    server.standing = {
      'standing': 'suspended',
      'suspended_until': '2026-10-21T02:00:00Z',
      'strikes_counting': 3,
      'strike_days': 180,
      'strikes': [strike()],
    };

    await tester.pumpWidget(app(const AccountStatusScreen(standingToken: 'standing-token')));
    await tester.pumpAndSettle();

    expect(server.authorizations.last, 'Bearer standing-token');
    expect(find.textContaining('Suspended Until Oct 21, 2026'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    // No way past it but signing out.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a report about you shows the rule and your content, never the reporter', (tester) async {
    RenderHarness.stubPlatformChannels(tester);
    phone(tester);
    server.report = {
      'id': 9,
      'reason': 'Misleading job post',
      'rule': 'The work, pay, or location was not what was advertised.',
      'content': {'kind': 'Job post', 'title': 'Paint a gate', 'text': '1500 for one day'},
      'filed_at': '2026-10-14T01:00:00Z',
      'reply_by': '2026-10-16T01:00:00Z',
      'status': 'pending',
      'outcome': null,
      'can_respond': true,
      'response': null,
      'photos_sent': 0,
    };

    await tester.pumpWidget(app(const ReportResponseScreen(reportId: 9)));
    await tester.pumpAndSettle();

    expect(find.text('Misleading job post'), findsOneWidget);
    expect(find.text('The work, pay, or location was not what was advertised.'), findsOneWidget);
    expect(find.text('Paint a gate'), findsOneWidget);
    expect(find.textContaining('Nothing is decided before Oct 16, 2026'), findsOneWidget);
    expect(find.textContaining('Photos or screenshots'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I paid exactly what the chat agreed.');
    await tester.pump();
    await tester.ensureVisible(find.text('Send My Side'));
    await tester.tap(find.text('Send My Side'));
    await tester.pumpAndSettle();

    expect(server.calls, contains('POST /reports/9/respond'));
    await tester.pump(const Duration(seconds: 4));
  });

  test('a strike notification opens Account status', () {
    expect(
      notificationDestination(type: 'moderation.strike', audience: 'both', referenceType: 'strike', referenceId: 4),
      NotificationDestination.accountStatus,
    );
  });
}

class _FakeServer implements HttpClientAdapter {
  Map<String, dynamic> standing = const {};
  Map<String, dynamic> report = const {};
  final List<String> calls = [];
  final List<String?> authorizations = [];
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    calls.add('${options.method} $path');
    authorizations.add(options.headers['Authorization'] as String?);
    if (options.data is Map) lastBody = (options.data as Map).cast<String, dynamic>();

    if (options.method == 'GET' && path.endsWith('/account/standing')) {
      return _json({'success': true, 'data': standing});
    }
    if (options.method == 'GET' && path.contains('/reports/')) {
      return _json({'success': true, 'data': report});
    }
    return _json({'success': true, 'data': null, 'message': 'ok'});
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}
