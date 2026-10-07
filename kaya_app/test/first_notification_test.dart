import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
    A new account's first notification is announced.

    The poll read "nothing seen yet" off a high-water mark of 0, which is
    also what an account with no notifications looks like. Every poll was
    "the first one", and the first notification an account ever received
    was taken as the starting point - no banner, nothing on the shade.
*/
void main() {
  AppNotification make(int id) => AppNotification(
        id: id,
        type: 'job.match',
        audience: 'worker',
        title: 'New job for you',
        isRead: false,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an empty first poll still counts as the first look', () async {
    final provider = NotificationProvider();
    final announced = <int>[];
    provider.arrived.addListener(() {
      final n = provider.arrived.value;
      if (n != null) announced.add(n.id);
    });

    provider.absorbPolled([]);
    provider.absorbPolled([make(1)]);

    expect(announced, [1]);
  });

  test('a backlog on the first look is still not replayed', () async {
    final provider = NotificationProvider();
    final announced = <int>[];
    provider.arrived.addListener(() {
      final n = provider.arrived.value;
      if (n != null) announced.add(n.id);
    });

    provider.absorbPolled([make(3), make(2)]);
    provider.absorbPolled([make(4), make(3)]);

    expect(announced, [4]);
  });
}
