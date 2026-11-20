import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/loading.dart';

void main() {
  testWidgets('Please wait stays up until the task ends, and back cannot close it', (tester) async {
    final done = Completer<int>();
    int? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await withPleaseWait(context, () => done.future),
          child: const Text('Go'),
        ),
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(find.text('Please wait...'), findsOneWidget);

    // Back does nothing while it waits.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Please wait...'), findsOneWidget);

    done.complete(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Please wait...'), findsNothing);
    expect(result, 7);
  });

  testWidgets('the pop-up closes when the task fails too', (tester) async {
    Object? caught;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            try {
              await withPleaseWait<void>(context, () async => throw StateError('offline'));
            } catch (e) {
              caught = e;
            }
          },
          child: const Text('Go'),
        ),
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Please wait...'), findsNothing);
    expect(caught, isA<StateError>());
  });

  testWidgets('a loading list draws placeholder cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingList(count: 3))));
    expect(find.byType(LoadingList), findsOneWidget);
    expect(tester.getSize(find.byType(LoadingList)).height, greaterThan(100));
  });
}
