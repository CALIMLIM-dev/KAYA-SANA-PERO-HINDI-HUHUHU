import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kaya_app/main.dart' as app;

/*
    The whole app on a real Android (MuMu), against a real server.

    Nothing here is faked: the app is the debug build, the server is the
    Laravel backend running on the PC on the TEST database, seeded by
    E2eSeeder. The phone reaches it through `adb reverse tcp:8000 tcp:8000`.

        cd kaya_backend
        php artisan migrate:fresh --seed            (DB_DATABASE=kaya_db_test)
        php artisan db:seed --class=CreditPackageSeeder
        php artisan db:seed --class=E2eSeeder
        cd public && php -S 127.0.0.1:8000 ../vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php

        adb reverse tcp:8000 tcp:8000
        flutter test integration_test/app_e2e_test.dart -d 127.0.0.1:16384 \
            --dart-define=API_BASE_URL=http://127.0.0.1:8000

    What a person does, checked on the server after each step: sign in,
    answer a hired worker in the chat (stored once), block them (the chat
    closes on both sides), and unblock them from Settings.
*/

const _base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');
const _password = 'KayaE2e2026!';
const _employer = 'e2e.employer@e2e.kaya.test';
const _worker = 'e2e.worker@e2e.kaya.test';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final server = Dio(BaseOptions(
    baseUrl: '$_base/api/v1',
    headers: {'Accept': 'application/json'},
    validateStatus: (_) => true,
  ));

  Future<String> tokenFor(String email) async {
    final res = await server.post('/login', data: {'email': email, 'password': _password});
    return res.data['data']['token'] as String;
  }

  /// Waits for [finder] in real time, pumping frames. On a timeout it lists
  /// what is on screen, so a failure says where the app actually was.
  Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final onScreen = find.byType(Text).evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .take(40)
        .join(' | ');
    fail('Timed out waiting for $finder. On screen: $onScreen');
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('employer signs in, answers in the chat, blocks and unblocks', (tester) async {
    final workerToken = await tokenFor(_worker);
    final asWorker = Options(headers: {'Authorization': 'Bearer $workerToken'});

    final threads = await server.get('/conversations', options: asWorker);
    final page = threads.data['data'];
    final threadId = ((page is Map ? page['data'] : page) as List).first['id'] as int;

    // main() installs the app's own error screen; the test's goes back at
    // the end of the body (the framework checks before any tearDown runs).
    final testErrorBuilder = ErrorWidget.builder;

    app.main();

    // A first open: the introduction, then Sign In.
    await tapAndSettle(tester, find.text('Skip'));
    await waitFor(tester, find.text('Sign In'));
    await tester.enterText(find.widgetWithText(TextField, 'Enter your email'), _employer);
    await tester.enterText(find.widgetWithText(TextField, 'Enter your password'), _password);
    await tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'Sign In'));

    // Home, then the chat with the hired worker.
    await tapAndSettle(tester, find.text('Messages'), );
    await tapAndSettle(tester, find.text('Ben Santos'));
    await waitFor(tester, find.text('Magandang araw po. Kailan po ako pwedeng magsimula?'));

    // Letters only to tell this run's message apart: a run of digits is
    // masked as a phone number by the chat filter, as it should be.
    final mark = DateTime.now().millisecondsSinceEpoch.toRadixString(26)
        .split('').map((c) => String.fromCharCode(97 + int.parse(c, radix: 26))).join();
    final reply = 'Bukas po ng umaga, $mark.';
    await tester.enterText(find.widgetWithText(TextField, 'Type a message...'), reply);
    await tester.tap(find.byIcon(Icons.send));
    await waitFor(tester, find.text(reply));

    // Stored once, and the worker sees it.
    await Future<void>.delayed(const Duration(seconds: 2));
    final seen = await server.get('/conversations/$threadId/messages', options: asWorker);
    final texts = (seen.data['data']['data'] as List).map((m) => m['message_text']).toList();
    expect(texts.where((t) => t == reply).length, 1, reason: 'one message on the server, not two');

    // Block from the chat menu: it asks, then the chat closes.
    await tapAndSettle(tester, find.byType(PopupMenuButton<String>).last);
    await tapAndSettle(tester, find.text('Block User'));
    await waitFor(tester, find.text('Block Ben Santos?'));
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Block'));
    await waitFor(tester, find.text('Messages'));

    final blocked = await server.get('/conversations/$threadId/messages', options: asWorker);
    expect(blocked.statusCode, 403, reason: 'the worker cannot read the thread either');

    // Unblock from Settings.
    await tapAndSettle(tester, find.text('Profile'));
    // Two "Settings" on the profile: the heading, then the row under it.
    await waitFor(tester, find.text('Settings'));
    await tester.ensureVisible(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Settings').last, warnIfMissed: false);
    await waitFor(tester, find.text('Change Password'));
    await tapAndSettle(tester, find.text('Blocked Accounts'));
    await waitFor(tester, find.text('Ben Santos'));
    await tapAndSettle(tester, find.text('Unblock'));
    await waitFor(tester, find.text('You have not blocked anyone.'));

    final open = await server.get('/conversations/$threadId/messages', options: asWorker);
    expect(open.statusCode, 200, reason: 'unblocked: the thread is back');

    ErrorWidget.builder = testErrorBuilder;
  });
}
