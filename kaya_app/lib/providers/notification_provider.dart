import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/constants/app_mode.dart';
import '../core/utils/json_parse.dart';
import '../data/services/api_client.dart';
import '../data/services/realtime_service.dart';

/// One notification, exactly as both the REST list and the socket deliver it.
///
/// The server defines this shape once (UserNotification::toPayload) precisely so
/// a live-arriving notification and the same row after a refresh cannot render
/// differently.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.audience,
    required this.title,
    this.body,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    this.createdAt,
    this.age,
  });

  final int id;
  final String type;
  final String audience;
  final String title;
  final String? body;
  final String? referenceType;
  final int? referenceId;
  final bool isRead;
  final DateTime? createdAt;
  final String? age;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: asInt(json['id']),
      type: '${json['type'] ?? ''}',
      audience: '${json['audience'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: json['body'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: asIntOrNull(json['reference_id']),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      age: json['age'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        audience: audience,
        title: title,
        body: body,
        referenceType: referenceType,
        referenceId: referenceId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        age: age,
      );
}

/// The notification centre's state.
///
/// REST is the source of truth and the socket is an accelerant, never the other
/// way round. Everything here works with the socket down — it just costs the
/// user a pull-to-refresh. Building it the other way (socket-first, REST as
/// fallback) is how apps end up permanently stale after one dropped connection.
///
/// Unread counts come from the server rather than being derived locally. For a
/// hybrid account the badge is per-mode, and a client that only knows "one more
/// arrived" cannot tell which badge to move without re-implementing audience
/// rules it has no business owning.
class NotificationProvider with ChangeNotifier {
  NotificationProvider() {
    _listen();
  }

  final ApiClient _api = ApiClient();

  List<AppNotification> _items = [];
  int _unreadWorker = 0;
  int _unreadEmployer = 0;
  int _unreadTotal = 0;
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  VoidCallback? _disposeListener;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;

  int get unreadWorker => _unreadWorker;
  int get unreadEmployer => _unreadEmployer;

  /// Held separately rather than added up: a shared notification counts towards
  /// both badges, so worker + employer would count every message twice. The
  /// server sends this already counted, the same way it sends the other two.
  int get unreadTotal => _unreadTotal;

  /// The badge for the mode the user is currently in. A neutral account (no
  /// profiles yet) sees everything, which matches what the list shows them.
  /// `all` and a neutral account both show everything, for the same reason:
  /// the badge has to agree with the list underneath it, and both of those
  /// show the lot.
  int unreadFor(AppMode? mode) => switch (mode) {
        AppMode.worker => _unreadWorker,
        AppMode.employer => _unreadEmployer,
        AppMode.all => unreadTotal,
        null => unreadTotal,
      };

  /// Notifications for the active mode. Filtered client-side because the full
  /// list is already loaded — refetching on every mode toggle would make the
  /// switch feel slow for no gain.
  List<AppNotification> itemsFor(AppMode? mode) {
    // Both of these show everything, so neither filters.
    if (mode == null || mode == AppMode.all) return items;
    final wanted = mode == AppMode.worker ? 'worker' : 'employer';
    // 'both' belongs to whichever mode is showing. Messages use it, because the
    // inbox is not filtered by mode either — hiding the alert for a thread the
    // user can plainly see is how a hybrid misses a message. Mirrors
    // UserNotification::scopeForAudience on the server.
    return _items
        .where((n) => n.audience == wanted || n.audience == 'both')
        .toList(growable: false);
  }

  // ── loading ────────────────────────────────────────────────────────────────

  /// Loads the whole inbox (both audiences) so mode switching is instant.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoadedOnce && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/notifications', queryParameters: {
        'per_page': 50,
      });

      final payload = response.data['data'];
      final rows = payload is Map ? payload['data'] : payload;

      _items = (rows as List? ?? [])
          .whereType<Map>()
          .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      _recountFromItems();
      _hasLoadedOnce = true;
    } catch (e) {
      _error = 'Could not load notifications';
      debugPrint('[notifications] load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  // ── mutations ──────────────────────────────────────────────────────────────

  /// Marks one read. Applied locally first so the row responds to the tap
  /// immediately, then reverted if the server disagrees.
  Future<void> markRead(int id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].isRead) return;

    final previous = _items[index];
    _items[index] = previous.copyWith(isRead: true);
    _adjustUnread(previous.audience, -1);
    notifyListeners();

    try {
      await _api.patch('/notifications/$id/read');
    } catch (e) {
      _items[index] = previous;
      _adjustUnread(previous.audience, 1);
      notifyListeners();
      debugPrint('[notifications] markRead failed: $e');
    }
  }

  /// Clears the badge for one mode only.
  ///
  /// Scoped on purpose: clearing in worker mode must not silently dismiss
  /// employer notifications the user has never seen. The server enforces the
  /// same scoping — this is not client-side politeness.
  Future<void> markAllRead(AppMode? mode) async {
    // A null audience means every notification, which is what `all` asks for
    // and what a profileless account already got.
    final audience = switch (mode) {
      AppMode.worker => 'worker',
      AppMode.employer => 'employer',
      AppMode.all => null,
      null => null,
    };

    final snapshot = List.of(_items);
    final beforeWorker = _unreadWorker;
    final beforeEmployer = _unreadEmployer;
    final beforeTotal = _unreadTotal;

    /*
        Shared rows are cleared too, and must be.

        They are shown in whichever mode is open, so "mark all read" from here
        visibly covers them — and the server agrees, because forAudience()
        matches them in both modes. Leaving them unread locally would put the
        badge and the list it opens into disagreement until the next fetch.
    */
    bool inScope(AppNotification n) =>
        audience == null || n.audience == audience || n.audience == 'both';

    final clearedShared =
        _items.where((n) => !n.isRead && n.audience == 'both').length;

    _items = _items
        .map((n) => inScope(n) ? n.copyWith(isRead: true) : n)
        .toList();

    if (audience == null) {
      _unreadWorker = 0;
      _unreadEmployer = 0;
    } else if (audience == 'worker') {
      _unreadWorker = 0;
      // The shared ones just left the other badge as well.
      _unreadEmployer = (_unreadEmployer - clearedShared).clamp(0, 1 << 30);
    } else {
      _unreadEmployer = 0;
      _unreadWorker = (_unreadWorker - clearedShared).clamp(0, 1 << 30);
    }

    // Nothing shared is unread any more, so the badges no longer overlap and
    // adding them is exact again.
    _unreadTotal = _unreadWorker + _unreadEmployer;
    notifyListeners();

    try {
      await _api.post(
        '/notifications/read-all',
        data: audience == null ? null : {'audience': audience},
      );
    } catch (e) {
      _items = snapshot;
      _unreadWorker = beforeWorker;
      _unreadEmployer = beforeEmployer;
      _unreadTotal = beforeTotal;
      notifyListeners();
      debugPrint('[notifications] markAllRead failed: $e');
    }
  }

  /// Wipes state on logout so the next account doesn't inherit a badge count.
  void clear() {
    _items = [];
    _unreadWorker = 0;
    _unreadEmployer = 0;
    _unreadTotal = 0;
    _hasLoadedOnce = false;
    _error = null;
    // Reset the watermark too, or the next account to sign in on this handset
    // starts with the previous one's highest id and sees no banners until it
    // is passed.
    _newestSeenId = 0;
    stopPolling();
    notifyListeners();
  }

  // ── realtime ───────────────────────────────────────────────────────────────

  void _listen() {
    final realtime = RealtimeService.instance;

    // The user id isn't known until the socket has its config, so subscribing
    // is deferred until the connection reports up.
    realtime.connected.addListener(_onConnectionChanged);
    _onConnectionChanged();
  }

  void _onConnectionChanged() {
    final realtime = RealtimeService.instance;
    final userId = realtime.userId;

    if (!realtime.connected.value || userId == null) return;
    if (_disposeListener != null) return;

    _disposeListener = realtime.on(
      'user.$userId',
      'notification.created',
      _onPushed,
    );
  }

  /// The socket's entry point, exposed for tests.
  ///
  /// Named rather than made public so it reads as what it is at call sites, and
  /// so the merge logic can be tested without standing up a WebSocket server —
  /// de-duplication and the per-mode badge are exactly the things that fail
  /// silently and therefore need pinning.
  @visibleForTesting
  void debugHandlePush(Map<String, dynamic> data) => _onPushed(data);

  /*
      Polling, because the socket is not the delivery mechanism here.

      The in-app banner listened only to `notification.created` over the
      WebSocket. This project has no push provider by choice and Reverb is not
      part of the deployment, so that event never arrives and no banner ever
      appeared — the notification landed silently in the list instead.

      This asks the same endpoint the background service already polls, on the
      same cadence, and republishes anything genuinely new through `arrived`.
      Everything downstream then works whether a socket exists or not.
  */
  static const Duration _pollEvery = Duration(seconds: 8);

  Timer? _poll;
  int _newestSeenId = 0;

  /// Fires once per newly-arrived notification, newest last. The banner host
  /// listens to this; nothing else should need it.
  final ValueNotifier<AppNotification?> arrived = ValueNotifier(null);

  void startPolling() {
    _poll ??= Timer.periodic(_pollEvery, (_) => _pollOnce());
    _pollOnce();
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _pollOnce() async {
    try {
      final response = await _api.get('/notifications', queryParameters: {
        'per_page': 10,
      });

      final payload = response.data['data'];
      final rows = payload is Map ? payload['data'] : payload;

      final fetched = (rows as List? ?? [])
          .whereType<Map>()
          .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      absorbPolled(fetched);
    } catch (e) {
      // A missed poll is a late banner, not a failure worth surfacing.
      debugPrint('[notifications] poll failed: $e');
    }
  }

  /// The merge half of a poll, split out so it can be tested without a server.
  /// Announcing the same notification twice, or announcing a whole unread
  /// backlog on launch, both fail silently — they just look like a buggy app.
  @visibleForTesting
  void absorbPolled(List<AppNotification> fetched) {
    if (fetched.isEmpty) return;

    // First poll of a session only establishes the high-water mark. Without
    // this, opening the app would fire a banner for every unread backlog
    // item at once.
    if (_newestSeenId == 0) {
      _newestSeenId = fetched.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      return;
    }

    final fresh = fetched.where((n) => n.id > _newestSeenId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    if (fresh.isEmpty) return;

    _newestSeenId = fresh.last.id;

    for (final n in fresh) {
      _items.removeWhere((existing) => existing.id == n.id);
      _items.insert(0, n);
    }

    _recountFromItems();
    notifyListeners();

    for (final n in fresh) {
      arrived.value = n;
    }
  }

  void _onPushed(Map<String, dynamic> data) {
    final raw = data['notification'];
    if (raw is! Map) return;

    final notification =
        AppNotification.fromJson(Map<String, dynamic>.from(raw));

    // Keep the poll's high-water mark in step, so a pushed notification is not
    // re-announced by the next poll.
    if (notification.id > _newestSeenId) _newestSeenId = notification.id;

    // De-duplicate on id. A notification can arrive twice — once pushed, once
    // in a refresh that raced it — and appending blindly would show it twice.
    _items.removeWhere((n) => n.id == notification.id);
    _items.insert(0, notification);

    // Counts come from the server with the push, so the badge stays exact even
    // if a push was missed while the socket was down.
    final unread = data['unread'];
    if (unread is Map) {
      _unreadWorker = asInt(unread['worker']);
      _unreadEmployer = asInt(unread['employer']);
      // Sent already counted, because the two above overlap on shared rows.
      _unreadTotal = asInt(unread['total']);
    } else {
      _recountFromItems();
    }

    notifyListeners();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /*
      A shared notification counts towards BOTH badges.

      It shows in both lists, so a badge that only lit in one would send the
      user to a list that had already changed without warning them — and for a
      message, the other mode would show no bell at all for a thread sitting
      right there in the inbox.

      The two totals therefore overlap by design, which is why unreadTotal
      cannot simply add them.
  */
  void _recountFromItems() {
    bool unreadIn(AppNotification n, String audience) =>
        !n.isRead && (n.audience == audience || n.audience == 'both');

    _unreadWorker = _items.where((n) => unreadIn(n, 'worker')).length;
    _unreadEmployer = _items.where((n) => unreadIn(n, 'employer')).length;
    _unreadTotal = _items.where((n) => !n.isRead).length;
  }

  void _adjustUnread(String audience, int delta) {
    if (audience == 'worker' || audience == 'both') {
      _unreadWorker = (_unreadWorker + delta).clamp(0, 1 << 30);
    }
    if (audience == 'employer' || audience == 'both') {
      _unreadEmployer = (_unreadEmployer + delta).clamp(0, 1 << 30);
    }
    // Once, however many badges it touched.
    _unreadTotal = (_unreadTotal + delta).clamp(0, 1 << 30);
  }

  @override
  void dispose() {
    stopPolling();
    arrived.dispose();
    _disposeListener?.call();
    RealtimeService.instance.connected.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
