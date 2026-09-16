import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/navigation/app_router.dart';

/*
    Screens must not stack copies of themselves.

    A second tap on the same card, a notification for the job already open,
    or a chat opening the job that opened the chat all used to push another
    copy, and the person backed out through the same screen twice or three
    times. AppRouter.push refuses a route that is already on top with the
    same arguments and allows anything else.
*/
void main() {
  Widget app() => MaterialApp(
        navigatorObservers: [AppRouter.observer],
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text('at ${settings.name} ${settings.arguments ?? ''}'),
                TextButton(
                  onPressed: () => AppRouter.push(context, '/job', arguments: {'jobId': 7}),
                  child: const Text('open job 7'),
                ),
                TextButton(
                  onPressed: () => AppRouter.push(context, '/job', arguments: {'jobId': 8}),
                  child: const Text('open job 8'),
                ),
              ],
            ),
          ),
        ),
        initialRoute: '/home',
      );

  testWidgets('the same route with the same arguments is not pushed twice', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('open job 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open job 7').last);
    await tester.pumpAndSettle();

    expect(find.text('at /job {jobId: 7}'), findsOneWidget);

    // One back lands on home, not on another copy of the job.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('at /home '), findsOneWidget);
  });

  testWidgets('the same route with different arguments is allowed', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('open job 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open job 8').last);
    await tester.pumpAndSettle();

    expect(find.text('at /job {jobId: 8}'), findsOneWidget);
    expect(AppRouter.observer.top?.settings.arguments, {'jobId': 8});
  });
}
