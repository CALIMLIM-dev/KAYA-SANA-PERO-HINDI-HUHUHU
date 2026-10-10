import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/core/widgets/notification_banner.dart';
import 'package:kaya_app/providers/messaging_provider.dart';
import 'package:kaya_app/providers/notification_provider.dart';

import 'support/render_harness.dart';

/*
    Reported: the pop-up for a new notification did not appear while the
    app was open. Drives the whole path - a poll that finds something new,
    the provider announcing it, the host drawing the card - rather than any
    one piece of it.
*/
void main() {
  AppNotification message(int id) => AppNotification.fromJson({
        'id': id,
        'type': 'message.received',
        'audience': 'both',
        'title': 'New message',
        'body': 'Rosa Bautista: Pwede po ba bukas ng umaga?',
        'reference_type': 'conversation',
        'reference_id': 3,
      });

  Future<NotificationProvider> pumpHost(WidgetTester tester) async {
    RenderHarness.stubPlatformChannels(tester);
    final notifications = NotificationProvider();
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationProvider>.value(value: notifications),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
      ],
      child: MaterialApp(
        navigatorKey: key,
        builder: (context, child) => NotificationBannerHost(navigatorKey: key, child: child!),
        home: const Scaffold(body: Center(child: Text('Home'))),
      ),
    ));
    // The host attaches on the first frame that has a navigator.
    await tester.pump();
    return notifications;
  }

  testWidgets('a polled notification slides in over the screen', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final notifications = await pumpHost(tester);

    notifications.absorbPolled([]); // the first look only sets the line
    notifications.absorbPolled([message(41)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('New message'), findsOneWidget);
    expect(find.textContaining('Rosa Bautista'), findsOneWidget);

    // Leaves on its own.
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('New message'), findsNothing);
  });
}
