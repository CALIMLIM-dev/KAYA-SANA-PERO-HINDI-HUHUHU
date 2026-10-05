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
  String? _loadError;
  List<Map<String, dynamic>> _invitations = [];

  bool get isLoading => _isLoading;

  /*
      Two kinds of failure, kept apart.

      One field held both, so a refused Accept ("job is no longer
      available") was indistinguishable from the list failing to load: My
      Invitations swapped the whole list for an error page with Retry, and
      My Activity's Invited count turned to a dash. loadError is the list;
      errorMessage is the last thing tapped, falling back to the list's.
  */
  String? get loadError => _loadError;
  String? get errorMessage => _errorMessage ?? _loadError;

  /// The last action's failure, once - read by the card that showed it.
  String? takeActionError() {
    final m = _errorMessage;
    _errorMessage = null;
    return m;
  }
  List<Map<String, dynamic>> get invitations => _invitations;

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
      _loadError = null;
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
      _loadError = e.toString().replaceFirst('Exception: ', '');
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

  /*
      Tells a past employer this worker is free again.

      Lives here rather than with applications because it is the worker's
      half of a rehire - the mirror of sendInvitation above. Nothing is
      created locally: the result is a notification in somebody else's list,
      and the server answers with the sentence to show.
  */
  Future<bool> askForWorkAgain(int employerId) async {
    try {
      final res = await _api.post('/employers/$employerId/work-again');
      _lastMessage = res.data['message'] as String?;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// What the server said about the last ask, for the screen to show.
  String? _lastMessage;
  String? get lastMessage => _lastMessage;

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

  /*
      Everything this provider holds belongs to one account.

      Nothing called clear() on this class because it did not have one, so the
      next person to sign in on the same phone inherited the previous
      account's invitations - and, once the rehire list landed, the names,
      photos and ratings of everyone they had hired. Same failure the credits
      balance had, with worse contents.
  */
  void clear() {
    _invitations = [];
    _isLoading = false;
    _errorMessage = null;
    _loadError = null;
    notifyListeners();
  }
}
