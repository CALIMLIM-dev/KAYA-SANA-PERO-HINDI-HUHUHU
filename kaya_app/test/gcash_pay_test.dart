import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/credits/screens/gcash_pay_screen.dart';
import 'package:kaya_app/features/credits/screens/receipt_screen.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:provider/provider.dart';

void main() {
  const package = CreditPackage(id: 1, name: 'Load', credits: 25, amountPhp: 50);

  Widget app(Widget child) {
    final credits = CreditsProvider()..seedGcash({'qr_url': '', 'name': 'KAYA Payments', 'waiting': null});
    return ChangeNotifierProvider<CreditsProvider>.value(
      value: credits,
      child: MaterialApp(home: Scaffold(body: Center(child: Dialog(child: child)))),
    );
  }

  testWidgets('the pay pop-up shows the price and holds the button until the receipt is in', (tester) async {
    await tester.pumpWidget(app(const GcashPayForm(package: package)));

    expect(find.text('Pay with GCash'), findsOneWidget);
    expect(find.text('Pay exactly ₱50.00'), findsOneWidget);
    expect(find.text('KAYA Payments'), findsOneWidget);
    ElevatedButton button() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Get My Barya'));
    expect(button().onPressed, isNull);

    // A reference number alone is not enough: the screenshot is required too.
    await tester.enterText(find.byType(TextField), '1234 567 890123');
    await tester.pump();
    expect(button().onPressed, isNull);
  });

  testWidgets('a receipt shows its number, the GCash reference and that it is being checked', (tester) async {
    await tester.pumpWidget(app(const ReceiptView(justPaid: true, receipt: {
      'receipt_no': 'KAYA-000012',
      'package': 'Load',
      'credits': 25,
      'amount_php': 50,
      'method': 'gcash',
      'gcash_ref': '1234567890123',
      'check_status': 'unchecked',
      'paid_at': '2026-11-19T08:30:00Z',
    })));

    expect(find.text('25 Barya Added'), findsOneWidget);
    expect(find.text('KAYA-000012'), findsOneWidget);
    expect(find.text('1234567890123'), findsOneWidget);
    expect(find.text('Being Checked'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
  });
}
