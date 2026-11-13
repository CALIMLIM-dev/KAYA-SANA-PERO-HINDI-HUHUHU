import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/messaging/screens/chat_screen.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:kaya_app/providers/schedule_provider.dart';

import 'support/render_harness.dart';

/*
    The chat screen as somebody uses it: the thread loads, a message goes
    out once with its own key, and Block User in the menu asks first and
    then closes the chat.
*/
void main() {
  late _Server server;
  final auth = AuthProvider()..seedUser({'id': 1, 'name': 'Ana Reyes'});
  final messaging = MessagingProvider();
  final notifications = NotificationProvider();
  final schedule = ScheduleProvider();
  final mode = AppModeProvider();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    ApiClient.testAdapter = server;
  });
  tearDown(() => ApiClient.testAdapter = null);

  Future<void> openChat(WidgetTester tester) async {
    // Real fonts: the test font draws every letter as a wide box, which
    // overflows rows that fit on a phone.
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Held outside the tree, so a request still in flight when the test
    // closes the chat does not land on a disposed provider.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: messaging),
        ChangeNotifierProvider.value(value: notifications),
        ChangeNotifierProvider.value(value: schedule),
        ChangeNotifierProvider.value(value: mode),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  settings: const RouteSettings(arguments: {
                    'conversationId': 5,
                    'name': 'Maria Santos',
                    'otherUserId': 9,
                    'myRole': 'employer',
                    'otherRole': 'worker',
                  }),
                  builder: (_) => const ChatScreen(),
                )),
                child: const Text('Open Chat'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open Chat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Leaves the chat so its poll timer stops before the test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  }

  testWidgets('the thread loads and a message goes out once, with its key', (tester) async {
    await openChat(tester);

    expect(find.text('Maria Santos'), findsWidgets);
    expect(find.text('Kailan po kayo pwede?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Bukas po ng umaga.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 500));

    expect(server.sent, hasLength(1));
    expect(server.sent.single['message_text'], 'Bukas po ng umaga.');
    expect(server.sent.single['client_id'], isNotEmpty);
    expect(find.text('Bukas po ng umaga.'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Block User asks first, blocks, and closes the chat', (tester) async {
    await openChat(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tap(find.text('Block User'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Block Maria Santos?'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(server.calls, contains('POST /users/9/block'));
    expect(find.byType(ChatScreen), findsNothing, reason: 'a blocked chat closes');

    await close(tester);
  });
}

class _Server implements HttpClientAdapter {
  final List<String> calls = [];
  final List<Map<String, dynamic>> sent = [];
  int _nextId = 100;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls.add('${o.method} ${o.path}');

    if (o.method == 'GET' && o.path.startsWith('/conversations/5/messages')) {
      final first = !o.path.contains('after_id');
      return _json({
        'success': true,
        'data': {
          'data': first
              ? [
                  {
                    'id': 10, 'conversation_id': 5, 'sender_id': 9, 'message_text': 'Kailan po kayo pwede?',
                    'created_at': '2026-11-13T08:00:00Z', 'sender': {'id': 9, 'name': 'Maria Santos'},
                  },
                ]
              : [],
        },
      });
    }
    if (o.method == 'POST' && o.path == '/conversations/5/messages') {
      final body = Map<String, dynamic>.from(o.data as Map);
      sent.add(body);
      return _json({
        'success': true,
        'data': {
          'id': _nextId++, 'conversation_id': 5, 'sender_id': 1, 'message_text': body['message_text'],
          'client_id': body['client_id'], 'created_at': '2026-11-13T08:01:00Z', 'sender': {'id': 1, 'name': 'Ana Reyes'},
        },
      }, 201);
    }
    if (o.method == 'POST' && o.path == '/users/9/block') {
      return _json({'success': true, 'data': null, 'message': 'Blocked Maria Santos.'}, 201);
    }
    return _json({'success': true, 'data': []});
  }

  ResponseBody _json(Map<String, dynamic> body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}
