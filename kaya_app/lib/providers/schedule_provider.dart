import 'package:flutter/foundation.dart';

import '../data/services/api_client.dart';

/*
    The day two people agree on for the work.

    Separate from the job's own dates on purpose. The post says when the work
    runs - the employer wrote that before anybody was hired. This is the other
    fact: these two settle on the Saturday of that week, one of them offers it
    and the other can say no. Neither replaces the other.

    It lives beside the conversation because that is where the agreeing
    happens, which is what makes it a schedule rather than a routine on a
    profile: both sides see the same offer, and both sides can refuse it.
*/
class ScheduleProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  /// conversation id → what is agreed, and what is still waiting.
  final Map<int, Map<String, dynamic>?> _agreed = {};
  final Map<int, Map<String, dynamic>?> _pending = {};

  String? _errorMessage;
  bool _busy = false;

  String? get errorMessage => _errorMessage;
  bool get busy => _busy;

  Map<String, dynamic>? agreedFor(int conversationId) => _agreed[conversationId];
  Map<String, dynamic>? pendingFor(int conversationId) => _pending[conversationId];

  Future<void> load(int conversationId) async {
    // No session, no schedule - and a request without one leaves a timeout
    // running behind it, the same guard every other provider uses.
    if (await ApiClient.getToken() == null) return;

    try {
      final res = await _api.get('/conversations/$conversationId/schedule');
      final data = res.data['data'] as Map<String, dynamic>;

      _agreed[conversationId] = data['agreed'] as Map<String, dynamic>?;
      _pending[conversationId] = data['pending'] as Map<String, dynamic>?;
      _errorMessage = null;
    } catch (e) {
      // A failed refresh is not an empty schedule: what was last known stays
      // on screen rather than the card vanishing mid-conversation.
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  /// Offers a day. Either side may; the other side answers.
  Future<bool> propose(
    int conversationId, {
    required DateTime date,
    required String period,
    String? note,
    int? jobId,
  }) async {
    _busy = true;
    notifyListeners();

    try {
      await _api.post('/conversations/$conversationId/schedule', data: {
        'scheduled_date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'period': period,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (jobId != null) 'job_id': jobId,
      });

      _errorMessage = null;
      await load(conversationId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Accepts or declines the live offer. Declining is an answer, not a
  /// failure - the next proposal is the counter-offer.
  Future<bool> respond(
    int conversationId,
    int proposalId, {
    required bool accept,
  }) async {
    _busy = true;
    notifyListeners();

    try {
      await _api.post(
        '/conversations/$conversationId/schedule/$proposalId/respond',
        data: {'accept': accept},
      );

      _errorMessage = null;
      await load(conversationId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Fills both maps for a test, which has no server to load from.
  @visibleForTesting
  void seedForTesting({
    required int conversationId,
    Map<String, dynamic>? agreed,
    Map<String, dynamic>? pending,
  }) {
    _agreed[conversationId] = agreed;
    _pending[conversationId] = pending;
    notifyListeners();
  }

  /// Wiped on logout with everything else, or the next account on this phone
  /// sees somebody else's arrangements.
  void clear() {
    _agreed.clear();
    _pending.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
