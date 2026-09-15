import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/utils/realtime_refresh.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:provider/provider.dart';

/*
    Screens refresh from the notification poll, not only from the socket.

    Reverb is off on the server, so the socket never connects and, before
    this, no self-refreshing screen ever refreshed. The poll announces each
    new notification through NotificationProvider.arrived; a screen whose
    refreshOn matches reloads once per burst, and ignores the rest.
*/
void main() {
  AppNotification make(int id, String type) => AppNotification(
        id: id,
        type: type,
        audience: 'employer',
        title: 't',
        isRead: false,
      );

  testWidgets('a matching notification from the poll reloads the screen once',
      (tester) async {
    final provider = NotificationProvider();
    final probe = _Probe();

    await tester.pumpWidget(
      ChangeNotifierProvider<NotificationProvider>.value(
        value: provider,
        child: MaterialApp(home: _Screen(probe)),
      ),
    );
    await tester.pump();

    // The first poll of a session only sets the high-water mark.
    provider.absorbPolled([make(1, 'application.received')]);
    await tester.pump();
    expect(probe.refreshes, 0);

    // A burst of two relevant and one irrelevant: one reload.
    provider.absorbPolled([
      make(4, 'review.received'),
      make(3, 'application.accepted'),
      make(2, 'application.received'),
    ]);
    await tester.pump();
    expect(probe.refreshes, 1);

    // Nothing the screen cares about: no reload.
    provider.absorbPolled([make(5, 'review.received')]);
    await tester.pump();
    expect(probe.refreshes, 1);

    // The listener goes with the screen.
    await tester.pumpWidget(const SizedBox());
    provider.absorbPolled([make(6, 'application.received')]);
    await tester.pump();
    expect(probe.refreshes, 1);
  });

  testWidgets('a screen with no provider above it still builds', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(MaterialApp(home: _Screen(probe)));
    await tester.pump();
    expect(find.text('screen'), findsOneWidget);
  });
}

class _Probe {
  int refreshes = 0;
}

class _Screen extends StatefulWidget {
  final _Probe probe;
  const _Screen(this.probe);

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with RealtimeRefresh {
  @override
  void initState() {
    super.initState();
    bindRealtimeRefresh();
  }

  @override
  List<String> get refreshOn => const ['application.'];

  @override
  void onRealtimeRefresh() => widget.probe.refreshes++;

  @override
  Widget build(BuildContext context) => const Text('screen');
}
