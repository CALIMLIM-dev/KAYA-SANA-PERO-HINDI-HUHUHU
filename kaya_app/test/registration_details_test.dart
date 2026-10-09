import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/auth/widgets/registration_details_form.dart';
import 'package:kaya_app/features/profile/widgets/rate_row.dart';

/*
    The panel: make the required registration details mandatory, and a
    comprehensive job seeker profile - which needs a rate the app can set.
*/
void main() {
  Future<RegistrationDetailsFormState> pumpForm(WidgetTester tester, {double width = 360}) async {
    tester.view.physicalSize = Size(width * 3, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final key = GlobalKey<RegistrationDetailsFormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RegistrationDetailsForm(key: key),
        ),
      ),
    ));
    return key.currentState!;
  }

  testWidgets('nothing filled in names every required field', (tester) async {
    final form = await pumpForm(tester);

    expect(form.collect(), isNull);
    await tester.pump();

    expect(find.text('Enter your first name'), findsOneWidget);
    expect(find.text('Enter your last name'), findsOneWidget);
    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.text('Enter your date of birth'), findsOneWidget);
  });

  testWidgets('a filled form sends what the server asks for', (tester) async {
    final form = await pumpForm(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Maria');
    await tester.enterText(fields.at(2), 'Santos');
    await tester.enterText(fields.at(4), '9171234567');
    form.setBirthdate(DateTime(1994, 3, 8));
    await tester.pump();

    expect(form.collect(), {
      'first_name': 'Maria',
      'last_name': 'Santos',
      'phone': '+639171234567',
      'birthdate': '1994-03-08',
    });
  });

  testWidgets('under eighteen is refused', (tester) async {
    final form = await pumpForm(tester);
    final now = DateTime.now();

    form.setBirthdate(DateTime(now.year - 17, now.month, now.day));
    form.collect();
    await tester.pump();

    expect(find.text('You must be 18 or older to use KAYA.'), findsOneWidget);
  });

  testWidgets('the form fits a 320px phone', (tester) async {
    await pumpForm(tester, width: 320);
    expect(find.text('Suffix (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rate row offers "to be discussed" and hands it back', (tester) async {
    RateChoice? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RateRow(
          label: null,
          rateMin: null,
          rateMax: null,
          rateUnit: null,
          byAgreement: false,
          onSave: (c) async {
            saved = c;
            return null;
          },
        ),
      ),
    ));

    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.text('Expected rate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('To be discussed'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved?.byAgreement, isTrue);
  });

  testWidgets('a rate needs a figure, and the top cannot be below the bottom', (tester) async {
    RateChoice? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RateRow(
          label: null, rateMin: null, rateMax: null, rateUnit: null, byAgreement: false,
          onSave: (c) async {
            saved = c;
            return null;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Expected rate'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the least you would take, in pesos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '800');
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('The upper figure cannot be below the lower one.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '1200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.min, 800);
    expect(saved?.max, 1200);
    expect(saved?.unit, 'day');
  });
}
