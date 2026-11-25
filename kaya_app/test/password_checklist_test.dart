import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/core/utils/password_check.dart';
import 'package:kaya_app/core/widgets/password_checklist.dart';
import 'package:kaya_app/features/auth/screens/reset_password_screen.dart';
import 'package:kaya_app/features/auth/screens/signup_screen.dart';
import 'package:kaya_app/features/profile/widgets/change_password_sheet.dart';
import 'package:kaya_app/providers/auth_provider.dart';

import 'support/render_harness.dart';

/// The checklist ticks what the server asks for, and Strong is what it takes.
void main() {
  Future<void> show(WidgetTester tester, Widget child, {double width = 412, double scale = 1.0}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: c!,
        ),
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: const RouteSettings(arguments: {'email': 'maria@example.com', 'code': '482917'}),
          builder: (_) => child,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PasswordChecklist), findsOneWidget, reason: 'The checklist never rendered.');
  }

  Finder tick() => find.descendant(of: find.byType(PasswordChecklist), matching: find.byIcon(Icons.check));

  testWidgets('it ticks as it is typed, and says Weak until it is Strong', (tester) async {
    await show(tester, const SignupScreen());
    expect(find.text('Letter'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Symbol'), findsOneWidget);
    expect(tick(), findsNothing);
    expect(find.text('Weak'), findsNothing, reason: 'Nothing typed, nothing to call weak.');

    final box = find.byType(TextField).at(1);
    for (final (text, ticks) in [('tambayan', 1), ('tambayan42', 2), ('tambayan42rocks', 2)]) {
      await tester.enterText(box, text);
      await tester.pump();
      expect(tick(), findsNWidgets(ticks), reason: text);
      expect(find.text('Weak'), findsOneWidget, reason: text);
    }

    await tester.enterText(box, 'tambayan42rocks!');
    await tester.pump();
    expect(tick(), findsNWidgets(3));
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('Weak'), findsNothing);
  });

  testWidgets('three ticks and still weak says why, once', (tester) async {
    await show(tester, const SignupScreen());
    await tester.enterText(find.byType(TextField).at(0), 'delacruz@gmail.com');
    final box = find.byType(TextField).at(1);

    for (final (text, why) in [
      ('ab1!', 'Password must be at least 8 characters'),
      ('Password1!', 'That password is one of the most commonly used. Pick another.'),
      ('delacruz2026!', 'Do not use your name or email address in your password'),
    ]) {
      await tester.enterText(box, text);
      await tester.pump();
      expect(tick(), findsNWidgets(3), reason: text);
      expect(find.text('Weak'), findsOneWidget, reason: text);
      expect(find.text(why), findsOneWidget, reason: text);
    }

    // Pressed: the field says it, and the checklist does not say it again.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Do not use your name or email address in your password'), findsOneWidget);
  });

  test('the same characters the server counts', () {
    expect(PasswordCheck.problem('Niño2026!'), isNull);
    expect(PasswordCheck.hasSymbol('niño'), isFalse, reason: 'ñ is a letter.');
    expect(PasswordCheck.hasSymbol('dalawang salita'), isTrue, reason: 'The server takes a space.');
    expect(PasswordCheck.problem('tambayan42rocks'), 'Use at least one letter, one number and one symbol');
  });

  testWidgets('Reset Password has it too, and no tick that is always on', (tester) async {
    await show(tester, const ResetPasswordScreen());
    expect(find.text('Password must contain:'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('Change Password has it too', (tester) async {
    await show(tester, const Scaffold(body: ChangePasswordSheet()));
    await tester.enterText(find.byType(TextFormField).at(1), 'tambayan42rocks!');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets('fits ${width.toInt()}px at text scale $scale', (tester) async {
        await show(tester, const SignupScreen(), width: width, scale: scale);
        await tester.enterText(find.byType(TextField).at(1), 'Password1!');
        await tester.pump();
        expect(find.text('Weak'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
