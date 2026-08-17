import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/utils/json_parse.dart';
import '../data/services/api_client.dart';
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

  Future<void> fetchMessages(int conversationId) async {
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
    _isMessagesLoading = true;
    _messagesError = null;
    notifyListeners();

    // Subscribed before the fetch, not after: a message sent in the gap between
    // the two would otherwise be missed by both — too late for the fetch, too
    // early for the socket. Subscribing first means the worst case is a
    // duplicate, which _mergeMessage discards.
    _watchThread(conversationId);

    try {
      final res = await _api.get('/conversations/$conversationId/messages');
      final page = res.data['data'] as Map<String, dynamic>;
      _messages = (page['data'] as List).cast<Map<String, dynamic>>();
      // Fire-and-forget: viewing the thread marks the other side's messages read.
      unawaited(_markRead(conversationId));
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      _messages = [];
    }

    _isMessagesLoading = false;
    notifyListeners();
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

  Future<bool> sendMessage(int conversationId, String text) async {
    try {
      final res = await _api.post('/conversations/$conversationId/messages',
          data: {'message_text': text});
      if (_activeConversationId == conversationId) {
        // Merged rather than appended: the server also pushes this same message
        // back over the socket (which is how a second device signed into this
        // account stays in step), so a blind append shows the sender their own
        // message twice.
        _mergeMessage(res.data['data'] as Map<String, dynamic>);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

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
