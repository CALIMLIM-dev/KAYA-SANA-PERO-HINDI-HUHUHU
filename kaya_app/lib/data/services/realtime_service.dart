import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

/// The app's single WebSocket connection to Laravel Reverb.
///
/// One connection is shared by everything — notifications, chat, tracking and
/// the self-refreshing lists. A socket per screen would multiply handshake and
/// authorisation cost for no benefit, and mobile radios punish idle
/// connections, so there is exactly one and screens attach listeners to it.
///
/// **Nothing here is required for the app to work.** Every screen that listens
/// also fetches over REST; the socket only saves it from having to fetch
/// *again*. That is deliberate — a dropped connection, a stopped Reverb
/// process or a captive-portal WiFi degrades KAYA to the pull-based behaviour
/// it had before realtime existed, rather than to a broken app showing stale
/// data forever.
///
/// ## Why this speaks the protocol directly
///
/// Reverb is Pusher-protocol compatible, but the obvious client
/// (`pusher_channels_flutter`) cannot be pointed at it: its `init()` takes a
/// Pusher `cluster` and exposes no host override, so it can only ever dial
/// Pusher's own servers. Self-hosted Reverb is unreachable through it.
///
/// The subset of the protocol actually needed is small — connect, read
/// `connection_established`, sign private channels via the server, subscribe,
/// dispatch events, answer pings — so it is implemented here rather than
/// depending on a package that would have to be replaced anyway.
class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  /// Channel name -> event name -> handlers.
  ///
  /// Keyed by channel so a reconnect can re-subscribe to exactly what was live,
  /// and a list per event so two widgets can watch the same stream without
  /// fighting over a single callback slot.
  final Map<String, Map<String, List<void Function(Map<String, dynamic>)>>>
      _listeners = {};

  /// Channels the server has confirmed. A channel can be listened to before the
  /// socket is up; it gets subscribed once there is a connection.
  final Set<String> _subscribed = {};

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  Timer? _reconnectTimer;
  Timer? _activityTimer;

  String? _socketId;
  int? _userId;
  bool _connecting = false;
  bool _wantConnection = false;
  int _attempt = 0;

  /// Whether the socket is usable right now. Screens may show a subtle
  /// "reconnecting" hint from this, but must never block on it.
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  int? get userId => _userId;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  /// Called once the user is authenticated. Safe to call repeatedly — both app
  /// start and login reach it, and a second call while connected is a no-op.
  Future<void> connect() async {
    _wantConnection = true;
    if (_connecting || connected.value) return;
    await _open();
  }

  /// Drops the connection and forgets every subscription.
  ///
  /// Must be called on logout. Without it the previous account's channels stay
  /// subscribed and the next user to sign in on this device inherits someone
  /// else's notifications.
  Future<void> disconnect() async {
    _wantConnection = false;
    _reconnectTimer?.cancel();
    _activityTimer?.cancel();
    _listeners.clear();
    _subscribed.clear();
    _socketId = null;
    _userId = null;
    connected.value = false;

    await _socketSub?.cancel();
    _socketSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  // ── subscriptions ──────────────────────────────────────────────────────────

  /// Listens for [event] on [channel]. Returns a disposer — call it from the
  /// widget's `dispose`, or the handler outlives the screen and fires against a
  /// deactivated State.
  ///
  /// [channel] is the bare name (`user.7`); the `private-` prefix is applied
  /// here so callers cannot get it subtly wrong.
  VoidCallback on(
    String channel,
    String event,
    void Function(Map<String, dynamic> data) handler, {
    bool private = true,
  }) {
    final name = private ? 'private-$channel' : channel;

    final events = _listeners.putIfAbsent(name, () => {});
    final wasIdle = events.isEmpty;
    events.putIfAbsent(event, () => []).add(handler);

    if (wasIdle) _subscribe(name);

    return () {
      final handlers = events[event];
      handlers?.remove(handler);
      if (handlers != null && handlers.isEmpty) events.remove(event);
      if (events.isEmpty) {
        _listeners.remove(name);
        _unsubscribe(name);
      }
    };
  }

  // ── connection ─────────────────────────────────────────────────────────────

  Future<void> _open() async {
    _connecting = true;

    try {
      final config = await _fetchConfig();
      if (config == null) {
        _connecting = false;
        _scheduleReconnect();
        return;
      }

      _userId = config.userId;

      final scheme = config.useTls ? 'wss' : 'ws';
      final uri = Uri.parse(
        '$scheme://${config.host}:${config.port}/app/${config.key}'
        '?protocol=7&client=kaya-flutter&version=1.0',
      );

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _socketSub = _channel!.stream.listen(
        _onFrame,
        onDone: _onClosed,
        onError: (Object e) {
          debugPrint('[realtime] socket error: $e');
          _onClosed();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[realtime] connect failed: $e');
      _connecting = false;
      _scheduleReconnect();
    }
  }

  void _onClosed() {
    connected.value = false;
    _socketId = null;
    _subscribed.clear();
    _connecting = false;
    _activityTimer?.cancel();

    // Listeners are deliberately kept: they describe what the app wants to be
    // watching, and are replayed once a connection comes back.
    if (_wantConnection) _scheduleReconnect();
  }

  /// Exponential backoff, capped. A phone that loses signal in a jeepney should
  /// not hammer the server for the whole ride, but should also recover quickly
  /// once signal returns — hence the short first retry and the 30s ceiling.
  void _scheduleReconnect() {
    if (!_wantConnection || _reconnectTimer?.isActive == true) return;

    _attempt = (_attempt + 1).clamp(1, 6);
    final seconds = [1, 2, 4, 8, 15, 30][_attempt - 1];

    debugPrint('[realtime] reconnecting in ${seconds}s (attempt $_attempt)');
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_wantConnection) _open();
    });
  }

  // ── protocol ───────────────────────────────────────────────────────────────

  void _onFrame(dynamic raw) {
    _resetActivityTimer();

    final frame = _asMap(raw);
    if (frame == null) return;

    final event = frame['event'] as String?;
    if (event == null) return;

    switch (event) {
      case 'pusher:connection_established':
        _onEstablished(frame['data']);
        return;

      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': {}});
        return;

      case 'pusher:pong':
        return;

      case 'pusher:error':
        debugPrint('[realtime] server error: ${frame['data']}');
        return;

      case 'pusher_internal:subscription_succeeded':
        final channel = frame['channel'] as String?;
        if (channel != null) _subscribed.add(channel);
        return;
    }

    if (event.startsWith('pusher:') || event.startsWith('pusher_internal:')) {
      return;
    }

    _dispatch(frame);
  }

  void _onEstablished(dynamic data) {
    final payload = _asMap(data);
    _socketId = payload?['socket_id'] as String?;
    if (_socketId == null) return;

    _attempt = 0;
    _connecting = false;
    connected.value = true;
    debugPrint('[realtime] connected (socket $_socketId)');

    // A reconnect starts from zero subscriptions server-side, so everything the
    // app is listening to has to be re-established. Without this the app looks
    // connected after a tunnel drop and silently receives nothing.
    for (final name in _listeners.keys.toList()) {
      _subscribe(name);
    }
  }

  void _dispatch(Map<String, dynamic> frame) {
    final channel = frame['channel'] as String?;
    final event = frame['event'] as String?;
    if (channel == null || event == null) return;

    final handlers = _listeners[channel]?[event];
    if (handlers == null || handlers.isEmpty) return;

    final data = _asMap(frame['data']);
    if (data == null) return;

    // Copy first: a handler may dispose itself, which mutates the list.
    for (final handler in List.of(handlers)) {
      try {
        handler(data);
      } catch (e) {
        debugPrint('[realtime] handler for $event threw: $e');
      }
    }
  }

  Future<void> _subscribe(String name) async {
    if (!connected.value || _socketId == null) return;
    if (_subscribed.contains(name)) return;

    // Public channels need no server grant.
    if (!name.startsWith('private-') && !name.startsWith('presence-')) {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': name},
      });
      return;
    }

    // Private channels must be signed by the server. This is what stops a
    // guessed channel name from streaming somebody else's data — the app
    // cannot authorise itself.
    try {
      final auth = await ApiClient().authorizeChannel(
        channelName: name,
        socketId: _socketId!,
      );

      if (auth == null) {
        debugPrint('[realtime] auth refused for $name');
        return;
      }

      // The socket may have dropped while the grant was in flight; a grant is
      // bound to the socket id it was issued for and is useless on a new one.
      if (!connected.value) return;

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': name, 'auth': auth},
      });
    } catch (e) {
      debugPrint('[realtime] auth failed for $name: $e');
    }
  }

  void _unsubscribe(String name) {
    _subscribed.remove(name);
    if (!connected.value) return;
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': name},
    });
  }

  void _send(Map<String, dynamic> frame) {
    try {
      _channel?.sink.add(jsonEncode(frame));
    } catch (e) {
      debugPrint('[realtime] send failed: $e');
    }
  }

  /// Reverb pings every 60s. If nothing arrives for appreciably longer than
  /// that the connection is dead in a way TCP has not noticed yet — common on
  /// mobile, where a lost radio leaves a socket that is open but useless. Treat
  /// silence as a drop and reconnect rather than sitting on a zombie.
  void _resetActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer(const Duration(seconds: 100), () {
      debugPrint('[realtime] no activity; assuming dead connection');
      _channel?.sink.close();
      _onClosed();
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<_RealtimeConfig?> _fetchConfig() async {
    try {
      final data = await ApiClient().getRealtimeConfig();
      if (data == null) return null;

      return _RealtimeConfig(
        key: '${data['key']}',
        host: '${data['host']}',
        port: _toInt(data['port']) ?? 8080,
        useTls: data['use_tls'] == true,
        userId: _toInt(data['user_id']),
      );
    } catch (e) {
      debugPrint('[realtime] config fetch failed: $e');
      return null;
    }
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  /// Reverb sends `data` as a JSON *string* on application events and as an
  /// object on some protocol frames, so both have to be handled.
  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class _RealtimeConfig {
  const _RealtimeConfig({
    required this.key,
    required this.host,
    required this.port,
    required this.useTls,
    required this.userId,
  });

  final String key;
  final String host;
  final int port;
  final bool useTls;
  final int? userId;
}
