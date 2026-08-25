import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/constants/app_colors.dart';
import 'package:kaya_app/core/theme/app_theme.dart';
import 'package:kaya_app/providers/notification_provider.dart';

/*
    Regression tests for defects testers found on a phone that every existing
    check passed.

    Each of these compiled cleanly, analyzed cleanly, and rendered fine in the
    screen tests. They were caught by a person tapping a button, which is the
    slowest and most expensive way to find a bug — so each one is pinned here
    instead.
*/
void main() {
  group('TC-407 — editing a job crashed on a type nobody declared', () {
    /*
        The screen built its category list like this:

          rows.map((c) => {'id': c.id, 'name': c.name, 'icon': iconFor(c.name)})

        Values are int, String and IconData, so Dart infers the map's value type
        as their least upper bound — Object, not dynamic. The getter promised
        List<Map<String, dynamic>>, and because Map is covariant that compiles
        without a murmur. The list is a List<Map<String, Object>> at runtime.

        Nothing failed until firstWhere: the compiler types `orElse` from the
        *declared* type while the real list demands its own, and the two do not
        match. On the phone that is a full-screen red error reading

          type '() => Map<String, dynamic>' is not a subtype of
          type '(() => Map<String, Object>)?' of 'orElse'

        and every job whose category had loaded from the API hit it.
    */

    List<Map<String, dynamic>> withoutTypeArgument() {
      final rows = [
        (id: 1, name: 'Plumbing'),
        (id: 2, name: 'Electrical'),
      ];
      // The original, unannotated form.
      return rows
          .map((c) => {'id': c.id, 'name': c.name, 'icon': Icons.plumbing})
          .toList();
    }

    List<Map<String, dynamic>> withTypeArgument() {
      final rows = [
        (id: 1, name: 'Plumbing'),
        (id: 2, name: 'Electrical'),
      ];
      // The fix: pin the element type so runtime matches the signature.
      return rows
          .map<Map<String, dynamic>>(
              (c) => {'id': c.id, 'name': c.name, 'icon': Icons.plumbing})
          .toList();
    }

    test('the unannotated form really does produce Map<String, Object>', () {
      final list = withoutTypeArgument();

      /*
          The declared type is a lie the compiler allows.

          Note it is NOT possible to assert the negative here: a
          Map<String, Object> also satisfies `is Map<String, dynamic>`, because
          dynamic is the top type and generics are covariant. That is exactly
          why the bug type-checks and only fails when a method signature is
          reified from the runtime type — which is what firstWhere's orElse
          does, and what the next test pins.
      */
      expect(list, isA<List<Map<String, Object>>>());
      expect(withTypeArgument(), isNot(isA<List<Map<String, Object>>>()),
          reason: 'the annotated form must NOT be the Object-typed variant');
    });

    test('and firstWhere with orElse throws on it — the reported crash', () {
      final list = withoutTypeArgument();

      expect(
        () => list.firstWhere(
          (c) => c['name'] == 'nothing matches this',
          orElse: () => {'icon': Icons.build},
        ),
        throwsA(isA<TypeError>()),
        reason: 'this is the exact failure testers screenshotted',
      );
    });

    test('the annotated form carries the type it declares', () {
      final list = withTypeArgument();

      expect(list, isA<List<Map<String, dynamic>>>());
      expect(list.first, isA<Map<String, dynamic>>());
    });

    test('and firstWhere with orElse now returns the fallback', () {
      final list = withTypeArgument();

      final result = list.firstWhere(
        (c) => c['name'] == 'nothing matches this',
        orElse: () => {'icon': Icons.build},
      );

      expect(result['icon'], Icons.build);
    });
  });

  group('pop-up banners — the polling path that replaced the socket', () {
    AppNotification make(int id, {String audience = 'worker'}) {
      return AppNotification.fromJson({
        'id': id,
        'type': 'message.received',
        'audience': audience,
        'title': 'New message',
        'body': 'hello',
        'reference_type': 'conversation',
        'reference_id': 900 + id,
        'is_read': false,
      });
    }

    test('the first poll announces nothing — it only sets the watermark', () {
      final provider = NotificationProvider();
      final announced = <int>[];
      provider.arrived.addListener(() {
        final n = provider.arrived.value;
        if (n != null) announced.add(n.id);
      });

      // Opening the app on a backlog of unread notifications must not fire a
      // banner for each one.
      provider.absorbPolled([make(3), make(2), make(1)]);

      expect(announced, isEmpty);
    });

    test('only genuinely newer notifications are announced, oldest first', () {
      final provider = NotificationProvider();
      provider.absorbPolled([make(3), make(2), make(1)]);

      final announced = <int>[];
      provider.arrived.addListener(() {
        final n = provider.arrived.value;
        if (n != null) announced.add(n.id);
      });

      provider.absorbPolled([make(5), make(4), make(3), make(2), make(1)]);

      expect(announced, [4, 5], reason: 'ids 1-3 were already seen');
    });

    test('polling the same page twice announces nothing the second time', () {
      final provider = NotificationProvider();
      provider.absorbPolled([make(1)]);
      provider.absorbPolled([make(2)]);

      final announced = <int>[];
      provider.arrived.addListener(() {
        final n = provider.arrived.value;
        if (n != null) announced.add(n.id);
      });

      provider.absorbPolled([make(2), make(1)]);

      expect(announced, isEmpty);
    });

    test('a polled notification lands in the list exactly once', () {
      final provider = NotificationProvider();
      provider.absorbPolled([make(1)]);
      provider.absorbPolled([make(2)]);
      // Same id arriving again — a poll racing a refresh.
      provider.absorbPolled([make(2)]);

      expect(provider.items.where((n) => n.id == 2).length, 1);
    });

    test('logging out resets the watermark for the next account', () {
      final provider = NotificationProvider();
      provider.absorbPolled([make(9)]);
      provider.clear();

      final announced = <int>[];
      provider.arrived.addListener(() {
        final n = provider.arrived.value;
        if (n != null) announced.add(n.id);
      });

      // A different account whose ids happen to be lower must still be able to
      // establish its own watermark rather than inheriting 9.
      provider.absorbPolled([make(4)]);
      provider.absorbPolled([make(5)]);

      expect(announced, [5]);
    });
  });

  group('dividers rendered as near-black lines', () {
    /*
        Reported from a phone: hard dark rules across the inbox and the public
        worker profile, while the same widget looked fine on the login screen.

        The cause was not the screens. 21 of the 27 dividers in the app were
        written as a bare Divider with no colour, so they resolved through
        ThemeData, which never set one — leaving the framework default, dark
        enough to read as black on these light surfaces. The six that looked
        right were the ones with a colour passed by hand.

        Pinned at the theme rather than per screen, because that is where the
        fix lives and because a new bare Divider added tomorrow must inherit
        the same light rule without anyone remembering to colour it.
    */
    testWidgets('a divider with no colour of its own renders light',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Divider(height: 1)),
      ));

      final divider = tester.widget<Divider>(find.byType(Divider));

      // Nothing on the widget, so the colour has to come from the theme.
      expect(divider.color, isNull);

      final context = tester.element(find.byType(Divider));
      final resolved = DividerTheme.of(context).color ??
          Theme.of(context).dividerColor;

      expect(resolved, AppColors.neutral200);
    });

    testWidgets('a divider that sets its own colour still wins', (tester) async {
      // The six explicit ones must not be flattened by the theme.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Divider(height: 1, color: AppColors.neutral300),
        ),
      ));

      expect(
        tester.widget<Divider>(find.byType(Divider)).color,
        AppColors.neutral300,
      );
    });
  });
}