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

  List<Map<String, dynamic>> _pastWorkers = [];
  bool _isPastWorkersLoading = false;
  bool _hasLoadedPastWorkers = false;
  int? _rehireCost;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get invitations => _invitations;

  /*
      People this employer has finished a job with.

      Derived on the server from completed applications, so there is nothing
      cached here that can go stale against the real history.
  */
  List<Map<String, dynamic>> get pastWorkers => _pastWorkers;
  bool get isPastWorkersLoading => _isPastWorkersLoading;

  /// Whether the list has arrived at least once. The spinner is gated on
  /// this rather than on loading alone, so a pull-to-refresh does not blank
  /// out rows that are already on screen.
  bool get hasLoadedPastWorkers => _hasLoadedPastWorkers;

  /// What re-inviting one of them costs. Null until the list has loaded, so
  /// the screen shows no price rather than a guessed one.
  int? get rehireCost => _rehireCost;

  @visibleForTesting
  void seedPastWorkers(List<Map<String, dynamic>> rows, {int? cost}) {
    _pastWorkers = rows;
    _rehireCost = cost;
    _hasLoadedPastWorkers = true;
    notifyListeners();
  }

  Future<void> fetchPastWorkers() async {
    _isPastWorkersLoading = true;
    notifyListeners();

    try {
      final response = await _api.get('/past-workers');
      final data = response.data['data'] as Map<String, dynamic>;

      _pastWorkers = ((data['workers'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      _rehireCost = (data['invite_cost'] as num?)?.toInt();
      _hasLoadedPastWorkers = true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[invitations] past workers failed: $e');
    } finally {
      _isPastWorkersLoading = false;
      notifyListeners();
    }
  }

  /// Still waiting on the worker's answer — the only ones worth counting or
  /// listing, since an accepted or declined invitation needs nothing further.
  /// Defined here rather than at each call site for the same reason as
  /// ApplicationProvider's buckets: two copies of a filter drift.
  List<Map<String, dynamic>> get pending =>
      _invitations.where((i) => i['status'] == 'pending').toList();

  /// Seed the list directly, so the pending filter and the screens that read
  /// it can be tested against known statuses without a server.
  @visibleForTesting
  void seedInvitations(List<Map<String, dynamic>> rows) {
    _invitations = rows;
    notifyListeners();
  }

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
      /*
          The last known list survives a failed refresh.

          This emptied it, which made a dropped request indistinguishable from
          having no invitations — and My Activity's shortcut would then show a
          confident "0" over a worker who actually had two people waiting on
          them. ApplicationProvider has always kept its list on error and only
          recorded the message; this was the odd one out, and the strip's
          "could not load" state relies on the two behaving the same way: an
          empty list plus an error means we genuinely could not ask, and is
          drawn as a dash rather than a zero.
      */
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
