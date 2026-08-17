import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';

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

  Future<void> fetchConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/conversations');
      final page = res.data['data'] as Map<String, dynamic>;
      _conversations = (page['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _conversations = [];
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
    _activeConversationId = conversationId;
    _isMessagesLoading = true;
    _messagesError = null;
    notifyListeners();

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
        _messages.add(res.data['data'] as Map<String, dynamic>);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _messagesError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
