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

  bool get isWorker => audience == 'worker';

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
  int get unreadTotal => _unreadWorker + _unreadEmployer;

  /// The badge for the mode the user is currently in. A neutral account (no
  /// profiles yet) sees everything, which matches what the list shows them.
  int unreadFor(AppMode? mode) => switch (mode) {
        AppMode.worker => _unreadWorker,
        AppMode.employer => _unreadEmployer,
        null => unreadTotal,
      };

  /// Notifications for the active mode. Filtered client-side because the full
  /// list is already loaded — refetching on every mode toggle would make the
  /// switch feel slow for no gain.
  List<AppNotification> itemsFor(AppMode? mode) {
    if (mode == null) return items;
    final wanted = mode == AppMode.worker ? 'worker' : 'employer';
    return _items.where((n) => n.audience == wanted).toList(growable: false);
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
    final audience = switch (mode) {
      AppMode.worker => 'worker',
      AppMode.employer => 'employer',
      null => null,
    };

    final snapshot = List.of(_items);
    final beforeWorker = _unreadWorker;
    final beforeEmployer = _unreadEmployer;

    _items = _items
        .map((n) => (audience == null || n.audience == audience)
            ? n.copyWith(isRead: true)
            : n)
        .toList();

    if (audience == null) {
      _unreadWorker = 0;
      _unreadEmployer = 0;
    } else if (audience == 'worker') {
      _unreadWorker = 0;
    } else {
      _unreadEmployer = 0;
    }
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
      notifyListeners();
      debugPrint('[notifications] markAllRead failed: $e');
    }
  }

  /// Wipes state on logout so the next account doesn't inherit a badge count.
  void clear() {
    _items = [];
    _unreadWorker = 0;
    _unreadEmployer = 0;
    _hasLoadedOnce = false;
    _error = null;
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

  void _onPushed(Map<String, dynamic> data) {
    final raw = data['notification'];
    if (raw is! Map) return;

    final notification =
        AppNotification.fromJson(Map<String, dynamic>.from(raw));

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
    } else {
      _recountFromItems();
    }

    notifyListeners();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _recountFromItems() {
    _unreadWorker = _items.where((n) => !n.isRead && n.isWorker).length;
    _unreadEmployer = _items.where((n) => !n.isRead && !n.isWorker).length;
  }

  void _adjustUnread(String audience, int delta) {
    if (audience == 'worker') {
      _unreadWorker = (_unreadWorker + delta).clamp(0, 1 << 30);
    } else {
      _unreadEmployer = (_unreadEmployer + delta).clamp(0, 1 << 30);
    }
  }

  @override
  void dispose() {
    _disposeListener?.call();
    RealtimeService.instance.connected.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
