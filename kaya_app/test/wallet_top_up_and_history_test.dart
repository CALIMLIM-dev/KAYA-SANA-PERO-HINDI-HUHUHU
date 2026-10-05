import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/credits/widgets/top_up_section.dart';
import 'package:kaya_app/features/credits/widgets/wallet_history.dart';
import 'package:kaya_app/providers/credits_provider.dart';

import 'support/render_harness.dart';

/*
    The wallet's Top-up card and its history.

    The checklist and the packages are one card, and the history is grouped
    by day with a name for every kind of line - it used to print the raw
    database word for anything it did not know, such as job_duration.
*/
void main() {
  const rows = [
    ComparisonRow(label: '20 free barya every month', free: true, toppedUp: true),
    ComparisonRow(
        label: 'Apply to a job (2 barya, about 10 a month on free barya)',
        free: true,
        toppedUp: true),
    ComparisonRow(
        label: 'Boost a job or profile to the top (8 barya, 3 days)',
        free: false,
        toppedUp: true),
    ComparisonRow(
        label: 'Full profile shown to employers when you apply',
        free: false,
        toppedUp: true),
  ];

  const packages = [
    CreditPackage(id: 1, name: 'Starter', credits: 50, amountPhp: 50),
    CreditPackage(id: 2, name: 'Regular', credits: 120, amountPhp: 100),
    CreditPackage(id: 3, name: 'Business Starter', credits: 600, amountPhp: 600),
  ];

  List<CreditEntry> entries() {
    final now = DateTime.now();
    return [
      CreditEntry(id: 1, delta: 100, balanceAfter: 134, reason: 'topup', isRefund: false, createdAt: now),
      CreditEntry(id: 2, delta: -8, balanceAfter: 34, reason: 'boost', isRefund: false,
          note: 'Rewire a sari-sari store in Barangay Nancayasan', createdAt: now),
      CreditEntry(id: 3, delta: -1, balanceAfter: 42, reason: 'job_duration', isRefund: false,
          createdAt: now.subtract(const Duration(days: 3))),
      CreditEntry(id: 4, delta: 20, balanceAfter: 43, reason: 'monthly_grant', isRefund: false,
          createdAt: now.subtract(const Duration(days: 3))),
    ];
  }

  Future<List<String>> pump(WidgetTester tester, Widget child,
      {double width = 412, double scale = 1.0}) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        complaints.add(d.exceptionAsString().split('\n').first);
        return;
      }
      previous?.call(d);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);
      tester.view.physicalSize = Size(width * 2, 6000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ));
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return complaints;
  }

  Widget topUp({bool toppedUp = false, void Function(CreditPackage)? onBuy}) =>
      TopUpSection(
        packages: packages,
        rows: rows,
        hasToppedUp: toppedUp,
        buying: false,
        onBuy: onBuy ?? (_) {},
      );

  testWidgets('the checklist and the packages are one card', (tester) async {
    await pump(tester, topUp());

    expect(find.text('Buy any package once. It never expires.'), findsOneWidget);
    expect(find.text('Boost a job or profile to the top (8 barya, 3 days)'),
        findsOneWidget);
    expect(find.text('₱600'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('an account that topped up is told it has it', (tester) async {
    await pump(tester, topUp(toppedUp: true));

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('On your account. It never expires.'), findsOneWidget);
  });

  testWidgets('a package button buys that package', (tester) async {
    CreditPackage? bought;
    await pump(tester, topUp(onBuy: (p) => bought = p));

    await tester.tap(find.text('₱100'));
    expect(bought?.id, 2);
  });

  testWidgets('history names every line and groups it by day', (tester) async {
    await pump(tester, WalletHistory(entries: entries(), loading: false));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Boosted to the top'), findsOneWidget);
    expect(find.text('Kept a job post up longer'), findsOneWidget);
    expect(find.text('job_duration'), findsNothing);
    expect(find.text('Balance 134'), findsOneWidget);
  });

  testWidgets('the Received filter hides what was spent', (tester) async {
    await pump(tester, WalletHistory(entries: entries(), loading: false));

    await tester.tap(find.text('Received').last);
    await tester.pump();

    expect(find.text('Topped up'), findsOneWidget);
    expect(find.text('Boosted to the top'), findsNothing);
  });

  testWidgets('the wallet shows only the newest lines, no totals or filter',
      (tester) async {
    await pump(tester,
        WalletHistory(entries: entries(), loading: false, previewRows: 3));

    expect(find.text('Topped up'), findsOneWidget);
    expect(find.text('Kept a job post up longer'), findsOneWidget);
    // The fourth line lives on the history screen.
    expect(find.text('Free monthly Barya'), findsNothing);
    expect(find.text('Spent'), findsNothing);
    expect(find.text('All'), findsNothing);
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('fits ${width.toInt()}px at scale $scale', (tester) async {
        final complaints = await pump(
          tester,
          Column(children: [
            topUp(toppedUp: true),
            const SizedBox(height: 16),
            WalletHistory(entries: entries(), loading: false),
          ]),
          width: width,
          scale: scale,
        );

        expect(find.text('₱600'), findsOneWidget);
        expect(find.text('Kept a job post up longer'), findsOneWidget);
        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
