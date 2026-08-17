import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/utils/json_parse.dart';
import '../data/services/api_client.dart';
import '../data/services/message_cache.dart';
import '../data/services/realtime_service.dart';

/// Messaging — GET /conversations, GET/POST /conversations/{id}/messages,
/// PATCH /conversations/{id}/read.
///
/// messages_list_screen and chat_screen previously held entirely hardcoded
/// conversations and message threads in local state; nothing was ever sent
/// to or read from the server, even though the backend (locked/unlocked
/// gating, unread counts) already worked.
class MessagingProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _conversations = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get conversations => _conversations;

  /// [silent] skips the loading spinner and leaves the existing list in place
  /// on failure. Used for background reconciliation — a realtime refresh that
  /// flashed a spinner over a list the user is reading, or blanked it because
  /// the network hiccuped, would be worse than the staleness it fixes.
  Future<void> fetchConversations({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await _api.get('/conversations');
      final page = res.data['data'] as Map<String, dynamic>;
      _conversations = (page['data'] as List).cast<Map<String, dynamic>>();
      _errorMessage = null;
    } catch (e) {
      if (!silent) {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _conversations = [];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Single conversation thread ───────────────────────────────────────────────

  bool _isMessagesLoading = false;
  String? _messagesError;
  List<Map<String, dynamic>> _messages = [];
  int? _activeConversationId;

  bool get isMessagesLoading => _isMessagesLoading;
  String? get messagesErrorMessage => _messagesError;
  List<Map<String, dynamic>> get messages => _messages;

  /// The thread currently open, or null when no chat is on screen.
  ///
  /// Read by the in-app notification banner: announcing "New message" for the
  /// conversation the user is already looking at, while the message itself is
  /// arriving on screen underneath the banner, reads as a glitch rather than
  /// as a notification.
  int? get activeConversationId => _activeConversationId;

  /// Loads a thread.
  ///
  /// [silent] is for the chat screen's fallback refresh, which runs while the
  /// socket is down. It differs in three ways that all exist to keep a refresh
  /// from looking like a bug to someone mid-conversation: no loading spinner,
  /// no blanking the thread if the request fails, and no repaint at all unless
  /// the messages actually changed.
  Future<void> fetchMessages(int conversationId, {bool silent = false}) async {
    // Drop the previous thread before loading a different one.
    //
    // Without this, opening conversation B shows conversation A's messages
    // until the request lands — you see someone else's chat under the new
    // person's name, which is alarming in a way a stale job listing is not.
    //
    // Guarded on the id so a retry of the same thread doesn't blank a chat the
    // user is reading.
    if (_activeConversationId != conversationId) {
      _messages = [];
    }

    _activeConversationId = conversationId;
    if (!silent) {
      _isMessagesLoading = true;
      _messagesError = null;
      notifyListeners();
    }

    // Subscribed before the fetch, not after: a message sent in the gap between
    // the two would otherwise be missed by both — too late for the fetch, too
    // early for the socket. Subscribing first means the worst case is a
    // duplicate, which _mergeMessage discards.
    _watchThread(conversationId);

    /*
        Paint from disk first.

        The thread is almost always already known, and waiting on the network
        to show it means a spinner where there could be content — 300ms on a
        good connection, and on a bad one for as long as the request takes.
        Loading the cache first makes the network decide how fresh the view is
        rather than whether there is a view at all.
    */
    if (!silent) {
      final cached = await MessageCache.instance.load(conversationId);
      if (cached.isNotEmpty && _activeConversationId == conversationId) {
        _messages = cached;
        _isMessagesLoading = false;
        notifyListeners();
      }
    }

    try {
      /*
          Ask only for what is new.

          The cursor is the newest server id already held. On a poll — which is
          most calls — the answer is an empty array of about fifty bytes rather
          than the whole thread, measured at 96% smaller and roughly thirty
          times faster. That difference is what makes polling usable on the
          connections this app actually runs on.

          Falls back to the full fetch when nothing is cached, which is the
          first open of a thread on a new device.
      */
      final cursor = await MessageCache.instance.latestId(conversationId);

      final res = await _api.get(cursor > 0
          ? '/conversations/$conversationId/messages?after_id=$cursor'
          : '/conversations/$conversationId/messages');

      final page = res.data['data'] as Map<String, dynamic>;
      final incoming = (page['data'] as List).cast<Map<String, dynamic>>();

      await MessageCache.instance.save(conversationId, incoming);

      final changed = incoming.isNotEmpty;

      // A delta is merged into what is held; a full fetch replaces it.
      _messages = cursor > 0
          ? await MessageCache.instance.load(conversationId)
          : incoming;

      // Fire-and-forget: viewing the thread marks the other side's messages
      // read. Skipped on a silent poll that found nothing new, so an idle chat
      // does not send a write every few seconds for no reason.
      if (!silent || changed) {
        unawaited(_markRead(conversationId));
      }

      if (!silent) {
        _isMessagesLoading = false;
        notifyListeners();
      } else if (changed) {
        notifyListeners();
      }
    } catch (e) {
      // A silent refresh must never blank a thread someone is reading — the
      // socket, or the next poll, will catch up.
      if (silent) return;

      _messagesError = e.toString().replaceFirst('Exception: ', '');
      _messages = [];
      _isMessagesLoading = false;
      notifyListeners();
    }
  }

  /// Call when leaving a chat screen.
  ///
  /// Without it the app keeps a subscription per thread the user has ever
  /// opened, and every one of those keeps firing handlers for a screen that is
  /// gone.
  void leaveThread() {
    _disposeThreadListener?.call();
    _disposeThreadListener = null;
    _disposeReadListener?.call();
    _disposeReadListener = null;
    _watchedConversationId = null;
    _activeConversationId = null;

    // Reconciles the inbox on the way out — unread counts were cleared
    // server-side while the thread was open, and the local preview patch is a
    // best guess at what the server will return. One request on exit is a
    // cheap way to make sure the list the user lands back on is the truth.
    unawaited(fetchConversations(silent: true));
  }

  Future<void> _markRead(int conversationId) async {
    try {
      await _api.patch('/conversations/$conversationId/read');
    } catch (_) {
      // Best-effort — an unread badge lingering an extra refresh isn't worth
      // surfacing an error for.
    }
  }

  /*
      Optimistic send.

      The message is on screen before the request leaves the phone, then
      reconciled with whatever the server says.

      This is the largest perceived-speed change available to this app, and it
      is worth being precise about why. The server stores a message in about
      13ms; almost everything a user feels is the round trip — roughly 300ms
      through the tunnel, and unbounded on poor mobile data. Waiting for that
      before drawing anything makes the app feel broken on exactly the
      connections most of its users have. Drawing first makes send feel
      instant on every connection, because it no longer involves the network
      at all.

      The honesty of it lives in the status field: a pending message is marked
      as still sending, and a failed one says so and offers a retry, rather
      than silently pretending to have arrived.
  */
  Future<bool> sendMessage(int conversationId, String text) async {
    // A local id, above every real one, so it sorts last and cannot collide
    // with a server id.
    final pendingId = MessageCache.pendingIdBase +
        DateTime.now().millisecondsSinceEpoch % 100000000;

    final optimistic = <String, dynamic>{
      'id': pendingId,
      'sender_id': _selfId,
      'sender': {'name': null},
      'message_text': text,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'read_at': null,
      'status': 'pending',
    };

    if (_activeConversationId == conversationId) {
      _messages = [..._messages, optimistic];
      notifyListeners();
    }
    await MessageCache.instance.save(conversationId, [optimistic]);

    try {
      final res = await _api.post('/conversations/$conversationId/messages',
          data: {'message_text': text});

      final real = Map<String, dynamic>.from(res.data['data'] as Map);

      await MessageCache.instance
          .replacePending(conversationId, pendingId, real);

      if (_activeConversationId == conversationId) {
        // Drop the placeholder, then merge rather than append: the server also
        // pushes this same message back over the socket (which is how a second
        // device signed into this account stays in step), so a blind append
        // shows the sender their own message twice.
        _messages = _messages.where((m) => m['id'] != pendingId).toList();
        _mergeMessage(real);
        notifyListeners();
      }

      return true;
    } catch (e) {
      await MessageCache.instance.markFailed(conversationId, pendingId);

      if (_activeConversationId == conversationId) {
        final index = _messages.indexWhere((m) => m['id'] == pendingId);
        if (index != -1) {
          _messages[index] = {..._messages[index], 'status': 'failed'};
        }
        notifyListeners();
      }

      // Deliberately not set as _messagesError: the thread is fine and still
      // readable, and one message that did not go is said on the message
      // itself rather than as a banner over the whole conversation.
      return false;
    }
  }

  /// Sends a failed message again, and removes the failed placeholder.
  Future<bool> retryMessage(int conversationId, int pendingId) async {
    final index = _messages.indexWhere((m) => m['id'] == pendingId);
    if (index == -1) return false;

    final text = '${_messages[index]['message_text'] ?? ''}';

    _messages = _messages.where((m) => m['id'] != pendingId).toList();
    notifyListeners();
    await MessageCache.instance.remove(conversationId, pendingId);

    return sendMessage(conversationId, text);
  }

  /// Who this device is signed in as, so an optimistic message renders on the
  /// correct side of the thread before the server has confirmed anything.
  int? _selfId;

  set selfId(int? id) => _selfId = id;

  // ── Realtime ───────────────────────────────────────────────────────────────

  VoidCallback? _disposeThreadListener;
  VoidCallback? _disposeReadListener;
  int? _watchedConversationId;
  VoidCallback? _disposeConnectionListener;

  /// Marks everything this user sent as seen.
  ///
  /// The frame carries no message ids — "everything sent before now has been
  /// read" is the whole of what a seen indicator means, and it stays correct
  /// even if a message was missed, whereas a list of ids has to be complete.
  void _onMessagesRead(int conversationId, Map<String, dynamic> data) {
    if (_activeConversationId != conversationId) return;

    // Both parties get this frame. Ignore your own reads — they say nothing
    // about whether the other person saw yours.
    final readerId = asIntOrNull(data['reader_id']);
    final me = RealtimeService.instance.userId;
    if (readerId == null || (me != null && readerId == me)) return;

    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (asIntOrNull(message['sender_id']) == readerId) continue;
      if (message['is_read'] == true) continue;

      _messages[i] = {
        ...message,
        'is_read': true,
        'read_at': data['read_at'],
      };
      changed = true;
    }

    if (changed) notifyListeners();
  }

  /// Subscribes to one thread, replacing any previous subscription.
  ///
  /// Only the open thread is watched. Subscribing to every conversation the
  /// user has would put a socket channel behind each one for the sake of a
  /// badge the list already gets from the notification feed.
  void _watchThread(int conversationId) {
    if (_watchedConversationId == conversationId &&
        _disposeThreadListener != null) {
      return;
    }

    _disposeThreadListener?.call();
    _disposeReadListener?.call();
    _watchedConversationId = conversationId;

    _disposeThreadListener = RealtimeService.instance.on(
      'conversation.$conversationId',
      'message.created',
      (data) => _onMessagePushed(conversationId, data),
    );

    _disposeReadListener = RealtimeService.instance.on(
      'conversation.$conversationId',
      'messages.read',
      (data) => _onMessagesRead(conversationId, data),
    );

    // A subscription made while the socket is down is remembered but not yet
    // established, so it has to be re-issued once a connection exists.
    _disposeConnectionListener ??= _bindConnectionRetry();
  }

  VoidCallback _bindConnectionRetry() {
    final realtime = RealtimeService.instance;
    void retry() {
      final id = _watchedConversationId;
      if (!realtime.connected.value || id == null) return;
      _disposeThreadListener?.call();
      _disposeThreadListener = realtime.on(
        'conversation.$id',
        'message.created',
        (data) => _onMessagePushed(id, data),
      );

      // Re-issued alongside the message listener, or a reconnect leaves the
      // ticks permanently stuck on "sent".
      _disposeReadListener?.call();
      _disposeReadListener = realtime.on(
        'conversation.$id',
        'messages.read',
        (data) => _onMessagesRead(id, data),
      );
    }

    realtime.connected.addListener(retry);
    return () => realtime.connected.removeListener(retry);
  }

  void _onMessagePushed(int conversationId, Map<String, dynamic> data) {
    // The user may have navigated on while the frame was in flight.
    if (_activeConversationId != conversationId) return;

    _mergeMessage(data);

    // The thread is on screen, so anything arriving is being read right now.
    unawaited(_markRead(conversationId));

    notifyListeners();
  }

  /// Inserts a message unless it is already present.
  ///
  /// De-duplication is on `id`, and it matters on both paths: the sender gets
  /// their own message back over the socket after already adding the REST
  /// response, and a reconnect can replay a message the fetch also returned.
  void _mergeMessage(Map<String, dynamic> message) {
    final id = asIntOrNull(message['id']);
    if (id == null) return;

    final existing = _messages.indexWhere((m) => asIntOrNull(m['id']) == id);
    if (existing != -1) {
      _messages[existing] = message;
    } else {
      _messages.add(message);
    }

    _touchConversation(message);
  }

  /// Moves a conversation to the top of the inbox and updates its preview.
  ///
  /// The inbox otherwise goes stale for messages *you* send. Incoming messages
  /// arrive with a notification, which the list screen listens for and reloads
  /// on — but the server deliberately never notifies you about your own action,
  /// so nothing tells your own inbox that its newest conversation changed. The
  /// row kept showing the previous message until a manual pull-to-refresh.
  ///
  /// Patched locally rather than re-fetching: the data needed is already in
  /// hand, and firing a request on every keystroke-ending send would be a lot
  /// of traffic to learn something we just did ourselves.
  void _touchConversation(Map<String, dynamic> message) {
    final conversationId = asIntOrNull(message['conversation_id']);
    if (conversationId == null) return;

    final index =
        _conversations.indexWhere((c) => asIntOrNull(c['id']) == conversationId);
    if (index == -1) return;

    final conversation = Map<String, dynamic>.from(_conversations[index]);
    conversation['latest_message'] = message;
    conversation['updated_at'] = message['created_at'];

    _conversations
      ..removeAt(index)
      ..insert(0, conversation);
  }

  @override
  void dispose() {
    _disposeThreadListener?.call();
    _disposeReadListener?.call();
    _disposeConnectionListener?.call();
    super.dispose();
  }
}
