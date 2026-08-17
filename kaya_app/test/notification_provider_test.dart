import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/constants/app_mode.dart';
import 'package:kaya_app/providers/notification_provider.dart';

/// Covers the parts of the notification centre that fail *silently*.
///
/// A duplicated row, a badge counting the wrong audience, or a notification
/// leaking into the wrong mode all render as plausible-looking UI — nothing
/// throws, nothing logs, and the bug only surfaces as "why does it say 3 when
/// there are 2". Those are the cases pinned here.
///
/// The push path is exercised through `debugHandlePush`, which is the same
/// entry point the socket calls, so these tests cover the real merge logic
/// rather than a reimplementation of it.
void main() {
  Map<String, dynamic> push({
    required int id,
    String audience = 'worker',
    String type = 'application.accepted',
    String title = "You're hired",
    bool isRead = false,
    int unreadWorker = 1,
    int unreadEmployer = 0,
    String? createdAt,
  }) {
    return {
      'notification': {
        'id': id,
        'type': type,
        'audience': audience,
        'title': title,
        'body': 'body',
        'reference_type': 'job',
        'reference_id': 42,
        'is_read': isRead,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'age': 'just now',
      },
      'unread': {
        'worker': unreadWorker,
        'employer': unreadEmployer,
        'total': unreadWorker + unreadEmployer,
      },
    };
  }

  group('pushed notifications', () {
    test('a pushed notification lands at the top of the list', () {
      final provider = NotificationProvider();

      provider.debugHandlePush(push(id: 1, title: 'First'));
      provider.debugHandlePush(push(id: 2, title: 'Second'));

      expect(provider.items.map((n) => n.id), [2, 1]);
      expect(provider.items.first.title, 'Second');
    });

    test('the same notification arriving twice is not duplicated', () {
      // Real cause: a push races a pull-to-refresh that already fetched the
      // same row. Appending blindly would show it twice with identical text,
      // which reads as the server double-sending.
      final provider = NotificationProvider();

      provider.debugHandlePush(push(id: 7));
      provider.debugHandlePush(push(id: 7));

      expect(provider.items.length, 1);
    });

    test('unread counts come from the server, not from counting rows', () {
      // The server's number is authoritative because it also accounts for rows
      // this client never received — e.g. anything pushed while the socket was
      // down. Deriving the badge locally would under-count after every drop.
      final provider = NotificationProvider();

      provider.debugHandlePush(
        push(id: 1, unreadWorker: 12, unreadEmployer: 4),
      );

      expect(provider.unreadWorker, 12);
      expect(provider.unreadEmployer, 4);
      expect(provider.unreadTotal, 16);
      expect(provider.items.length, 1);
    });
  });

  group('audience separation', () {
    test('each mode sees only its own notifications', () {
      final provider = NotificationProvider();

      provider.debugHandlePush(push(id: 1, audience: 'worker'));
      provider.debugHandlePush(
        push(id: 2, audience: 'employer', unreadWorker: 1, unreadEmployer: 1),
      );

      expect(provider.itemsFor(AppMode.worker).map((n) => n.id), [1]);
      expect(provider.itemsFor(AppMode.employer).map((n) => n.id), [2]);
    });

    test('a neutral account sees everything', () {
      // No profiles yet means no mode, and hiding half their notifications
      // behind a toggle they cannot use would strand them.
      final provider = NotificationProvider();

      provider.debugHandlePush(push(id: 1, audience: 'worker'));
      provider.debugHandlePush(
        push(id: 2, audience: 'employer', unreadWorker: 1, unreadEmployer: 1),
      );

      expect(provider.itemsFor(null).length, 2);
      expect(provider.unreadFor(null), 2);
    });

    test('the badge is per mode', () {
      final provider = NotificationProvider();

      provider.debugHandlePush(
        push(id: 1, audience: 'employer', unreadWorker: 3, unreadEmployer: 5),
      );

      expect(provider.unreadFor(AppMode.worker), 3);
      expect(provider.unreadFor(AppMode.employer), 5);
    });
  });

  group('clear', () {
    test('clear drops the inbox and the badge', () {
      // Guards against the next account to sign in on a shared device
      // inheriting the previous user's unread count.
      final provider = NotificationProvider();

      provider.debugHandlePush(push(id: 1, unreadWorker: 9));
      expect(provider.unreadTotal, 9);

      provider.clear();

      expect(provider.items, isEmpty);
      expect(provider.unreadTotal, 0);
      expect(provider.hasLoadedOnce, isFalse);
    });
  });

  group('listeners', () {
    test('a push notifies listeners so the badge rebuilds', () {
      final provider = NotificationProvider();
      var notified = 0;
      provider.addListener(() => notified++);

      provider.debugHandlePush(push(id: 1));

      expect(notified, 1);
    });
  });
}
