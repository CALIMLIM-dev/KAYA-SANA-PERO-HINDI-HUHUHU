import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/services/background_poll.dart';
import 'package:kaya_app/data/services/local_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
    The closed-app worker. It asks for what is newer than the last thing the
    person saw, puts each on the shade oldest first, moves the mark, and
    never replays a backlog on a fresh sign-in.
*/
void main() {
  late List<(int, String)> shown;
  late List<Uri> asked;

  setUp(() {
    shown = [];
    asked = [];
    LocalAlerts.testSink = (id, title, body) => shown.add((id, title));
  });

  tearDown(() => LocalAlerts.testSink = null);

  Fetch canned(int status, List<Map<String, dynamic>> rows) =>
      (uri, headers) async {
        asked.add(uri);
        expect(headers['Authorization'], 'Bearer tok');
        return (status, jsonEncode({'data': {'data': rows}}));
      };

  Future<SharedPreferences> prefsWith({int? lastSeen}) async {
    SharedPreferences.setMockInitialValues({
      BackgroundPoll.tokenKey: 'tok',
      BackgroundPoll.baseUrlKey: 'https://kaya.test',
      BackgroundPoll.lastSeenKey: ?lastSeen,
    });
    return SharedPreferences.getInstance();
  }

  test('shows what is newer than the mark, oldest first, and moves the mark', () async {
    final prefs = await prefsWith(lastSeen: 10);

    final ok = await BackgroundPoll.runOnce(prefs, fetch: canned(200, [
      {'id': 12, 'title': 'Accepted', 'body': 'b'},
      {'id': 11, 'title': 'New applicant', 'body': 'a'},
      {'id': 10, 'title': 'Old', 'body': 'seen already'},
    ]));

    expect(ok, isTrue);
    expect(asked.single.query, 'after_id=10&per_page=20');
    expect(shown, [(11, 'New applicant'), (12, 'Accepted')]);
    expect(prefs.getInt(BackgroundPoll.lastSeenKey), 12);
  });

  test('a fresh sign-in sets the mark without announcing the backlog', () async {
    final prefs = await prefsWith();

    await BackgroundPoll.runOnce(prefs, fetch: canned(200, [
      {'id': 7, 'title': 'x'},
      {'id': 3, 'title': 'y'},
    ]));

    expect(shown, isEmpty);
    expect(prefs.getInt(BackgroundPoll.lastSeenKey), 7);
  });

  test('a rejected token stops the job polling with it', () async {
    final prefs = await prefsWith(lastSeen: 5);

    await BackgroundPoll.runOnce(prefs, fetch: canned(401, []));

    expect(prefs.getString(BackgroundPoll.tokenKey), isNull);
    expect(shown, isEmpty);

    // Nothing to poll with any more: no request goes out.
    asked.clear();
    await BackgroundPoll.runOnce(prefs, fetch: canned(200, []));
    expect(asked, isEmpty);
  });

  test('a server error asks WorkManager to retry', () async {
    final prefs = await prefsWith(lastSeen: 5);
    expect(await BackgroundPoll.runOnce(prefs, fetch: canned(500, [])), isFalse);
  });
}
