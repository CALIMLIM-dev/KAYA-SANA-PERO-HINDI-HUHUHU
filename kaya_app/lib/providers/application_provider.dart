import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';

class ApplicationProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _applications = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get applications => _applications;

  List<Map<String, dynamic>> get active => _applications
      .where((a) => ['pending', 'accepted'].contains(a['status']))
      .toList();

  List<Map<String, dynamic>> get completed => _applications
      .where((a) => a['status'] == 'completed')
      .toList();

  List<Map<String, dynamic>> get history => _applications
      .where((a) => ['rejected', 'withdrawn'].contains(a['status']))
      .toList();

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }

  // ── Applicants for a job (employer view) ────────────────────────────────────

  bool _isApplicantsLoading = false;
  String? _applicantsError;
  List<Map<String, dynamic>> _applicants = [];

  bool get isApplicantsLoading => _isApplicantsLoading;
  String? get applicantsErrorMessage => _applicantsError;
  List<Map<String, dynamic>> get applicants => _applicants;

  /// GET /jobs/{job}/applicants — the data behind ViewApplicantsScreen, which
  /// previously showed five hardcoded names (Juan Dela Cruz, Pedro Santos...)
  /// regardless of who actually applied.
  /// Which job [_applicants] currently belongs to, so a different job's list
  /// isn't shown under the new job's header while its request is in flight.
  int? _applicantsJobId;

  Future<void> fetchApplicants(int jobId) async {
    // Same reason as JobProvider.fetchJobDetail: without this the employer
    // opens job B and sees job A's applicants for a moment. Worse here than on
    // a detail screen — Accept and Reject are right there, on the wrong people.
    if (_applicantsJobId != jobId) {
      _applicants = [];
      _applicantsJobId = jobId;
    }

    _isApplicantsLoading = true;
    _applicantsError = null;
    notifyListeners();

    try {
      final res = await _api.get('/jobs/$jobId/applicants');
      _applicants = (res.data['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _applicantsError = e.toString().replaceFirst('Exception: ', '');
      _applicants = [];
    }

    _isApplicantsLoading = false;
    notifyListeners();
  }

  /// Accepts/rejects by application_id and reflects the change in the local
  /// applicants list (separate from the my-applications list above).
  Future<bool> respondToApplicant(int applicationId, {required bool accept}) async {
    try {
      final res = await _api
          .patch('/applications/$applicationId/${accept ? 'accept' : 'reject'}');

      // Accepting can cancel the worker's other applications where the dates
      // clash. Recorded so the confirmation can say so — otherwise the change
      // only shows up as other employers' lists quietly shrinking.
      lastAcceptCancelledCount = 0;
      if (accept) {
        final body = res.data['data'];
        final cancelled = body is Map ? body['cancelled_applications'] : null;
        if (cancelled is List) lastAcceptCancelledCount = cancelled.length;
      }

      final idx = _applicants.indexWhere((a) => a['application_id'] == applicationId);
      if (idx != -1) {
        _applicants[idx]['application_status'] = accept ? 'accepted' : 'rejected';
        notifyListeners();
      }
      return true;
    } catch (e) {
      _applicantsError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMyApplications() async {
    _setLoading(true);
    try {
      final res = await _api.get('/my-applications');
      _applications = (res.data['data'] as List).cast<Map<String, dynamic>>();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> applyToJob(int jobId, {String? coverLetter}) async {
    try {
      final res = await _api.post('/jobs/$jobId/apply', data: {
        if (coverLetter != null) 'cover_letter': coverLetter,
      });
      _applications.insert(0, res.data['data'] as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> withdraw(int applicationId) async {
    try {
      await _api.delete('/applications/$applicationId');
      final idx = _applications.indexWhere((a) => a['id'] == applicationId);
      if (idx != -1) {
        _applications[idx]['status'] = 'withdrawn';
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// The message the server returned for the last completion — either "waiting
  /// for the other side" or "both confirmed". Read once by the caller so the
  /// screen can say which of the two happened.
  String? lastCompletionMessage;

  /// Marks this side of a hire done. Both parties call the same endpoint; which
  /// side you are is worked out from the job, not sent by the app.
  ///
  /// The work only counts as finished when both have confirmed, so this usually
  /// leaves the application where it was and the caller refetches to pick up
  /// the new timestamps.
  Future<bool> markComplete(int applicationId) async {
    try {
      final res = await _api.patch('/applications/$applicationId/complete');
      lastCompletionMessage = res.data['message'] as String?;

      final application = res.data['data']?['application'];
      if (application is Map<String, dynamic>) {
        final idx = _applications.indexWhere((a) => a['id'] == applicationId);
        if (idx != -1) _applications[idx] = application;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// How many of the worker's other applications were cancelled by the last
  /// accept, because their dates clashed with the job just hired for.
  ///
  /// Read once by the screen that called [accept] so it can say what happened.
  /// Other applications going quiet with no explanation reads as a bug in the
  /// app rather than as the feature it is.
  int lastAcceptCancelledCount = 0;

  Future<bool> accept(int applicationId) async {
    try {
      final res = await _api.patch('/applications/$applicationId/accept');

      final cancelled = res.data['data']?['cancelled_applications'];
      lastAcceptCancelledCount = cancelled is List ? cancelled.length : 0;

      final idx = _applications.indexWhere((a) => a['id'] == applicationId);
      if (idx != -1) {
        _applications[idx]['status'] = 'accepted';
        notifyListeners();
      }
      return true;
    } catch (e) {
      lastAcceptCancelledCount = 0;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> reject(int applicationId) async {
    try {
      await _api.patch('/applications/$applicationId/reject');
      final idx = _applications.indexWhere((a) => a['id'] == applicationId);
      if (idx != -1) {
        _applications[idx]['status'] = 'rejected';
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
