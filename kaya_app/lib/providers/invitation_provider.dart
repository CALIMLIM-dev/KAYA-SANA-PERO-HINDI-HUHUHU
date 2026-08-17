import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';

/// Worker's job invitations from employers — GET /my-invitations.
///
/// my_invitations_screen previously held four hardcoded invitations in local
/// state; Accept/Decline only flipped that local map, never called the
/// server, and "View Job" pushed /job-details with no id at all (there was no
/// real job to point at).
class InvitationProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _invitations = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get invitations => _invitations;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  Future<void> fetchMyInvitations() async {
    _setLoading(true);
    try {
      final res = await _api.get('/my-invitations');
      final page = res.data['data'] as Map<String, dynamic>;
      _invitations = (page['data'] as List).cast<Map<String, dynamic>>();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _invitations = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Returns the new/unlocked conversation id on success (accepting always
  /// creates or unlocks one — see InvitationController@accept), or null on
  /// failure.
  Future<int?> accept(int invitationId) async {
    try {
      final res = await _api.patch('/invitations/$invitationId/accept');
      final idx = _invitations.indexWhere((i) => i['id'] == invitationId);
      if (idx != -1) {
        _invitations[idx]['status'] = 'accepted';
        notifyListeners();
      }
      return (res.data['data'] as Map<String, dynamic>)['conversation_id'] as int?;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Invites a worker to apply to one of your jobs.
  ///
  /// The send side of invitations was never wired on the client. Two buttons
  /// in the app — "Invite to Apply" on a worker's profile and the invite
  /// action on the home screen — popped "Invitation sent!" and called nothing,
  /// so the worker never received the invitation the employer was told about.
  ///
  /// The endpoint has existed all along and enforces the rules: the job must
  /// be yours and open, the target must be a worker, not yourself, not
  /// suspended, and not already invited.
  Future<bool> sendInvitation({required int jobId, required int workerId}) async {
    try {
      await _api.post('/jobs/$jobId/invite', data: {'worker_id': workerId});
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> decline(int invitationId) async {
    try {
      await _api.patch('/invitations/$invitationId/decline');
      final idx = _invitations.indexWhere((i) => i['id'] == invitationId);
      if (idx != -1) {
        _invitations[idx]['status'] = 'declined';
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
