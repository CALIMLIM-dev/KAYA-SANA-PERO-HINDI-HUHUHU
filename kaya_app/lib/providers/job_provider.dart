import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/job_model.dart';
import '../data/services/api_client.dart';

/// Manages employer-side job posting/management, and the public job feed
/// (worker-mode home + search).
class JobProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _jobs = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get jobs => _jobs;

  /*
      The jobs still being worked on.

      Kept here rather than at each call site for the reason the applications
      count went wrong: the home card and the manage-jobs screen each carried
      their own copy of "active", the screen's grew to include a status the
      card's did not, and the card then showed a number the list disagreed
      with. One definition cannot drift from itself.
  */
  List<Map<String, dynamic>> get activeJobs => _jobs
      .where((j) => ['open', 'in_progress'].contains(j['status']))
      .toList();

  // ── Public job feed (worker-mode home + search) ─────────────────────────────

  bool _isPublicLoading = false;
  String? _publicError;
  List<Job> _publicJobs = [];

  bool get isPublicLoading => _isPublicLoading;
  String? get publicErrorMessage => _publicError;
  List<Job> get publicJobs => _publicJobs;

  /*
      Lets a test render this screen with something in it.

      Overflow is a content bug - a layout breaks on the address that runs to
      three lines, not on an empty field - so a test that renders against an
      empty provider checks the one case that always fits. The profile header
      overflowed for weeks with every screen test passing, because none of
      them had a profile.

      There is no other way in: the list is filled by a fetch, and a test has
      no server. Marked visibleForTesting so nothing in the app calls it.
  */
  @visibleForTesting
  void seedPublicJobs(List<Job> jobs) {
    _publicJobs = jobs;
    notifyListeners();
  }

  @visibleForTesting
  void seedMyJobs(List<Map<String, dynamic>> jobs) {
    _jobs = jobs;
    notifyListeners();
  }

  /// GET /jobs — the feed the mock _getMockJobs() in unified_home_screen and
  /// search_screen used to stand in for. Includes a per-job match_score when
  /// the signed-in account has a worker profile (see JobMatchService).
  Future<void> fetchPublicJobs({
    String? search,
    int? categoryId,
    String? location,
    List<int>? skillIds,
    /// Orders by distance from the signed-in worker's location. Ignored by the
    /// server for anyone without a worker profile — there is nowhere to
    /// measure from.
    bool nearestFirst = false,
    /// Hard cut-off in kilometres. The server answers 422 when the account has
    /// no location, rather than quietly returning everything.
    double? radiusKm,
  }) async {
    _isPublicLoading = true;
    _publicError = null;
    notifyListeners();

    try {
      final res = await _api.get('/jobs', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null) 'category_id': categoryId,
        if (location != null && location.isNotEmpty) 'location': location,
        if (skillIds != null && skillIds.isNotEmpty) 'skill_ids': skillIds,
        if (nearestFirst) 'sort': 'nearest',
        if (radiusKm != null) 'radius_km': radiusKm,
      });

      final page = res.data['data'] as Map<String, dynamic>;
      final rows = page['data'] as List;
      _publicJobs = rows.map((j) => Job.fromApi(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _publicError = e.toString().replaceFirst('Exception: ', '');
      _publicJobs = [];
    }

    _isPublicLoading = false;
    notifyListeners();
  }

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }

  // ── Fetch my jobs ─────────────────────────────────────────────────────────────

  Future<void> fetchMyJobs() async {
    _setLoading(true);
    try {
      final res = await _api.get('/jobs/my');
      _jobs = (res.data['data'] as List).cast<Map<String, dynamic>>();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  // ── Create job ────────────────────────────────────────────────────────────────

  /// A calendar date with no time and no timezone, which is what the schedule
  /// columns actually hold.
  ///
  /// `toIso8601String()` would append a time and a Z, and the server would then
  /// compare that instant against midnight local — rejecting a job that starts
  /// today as starting in the past whenever the phone is ahead of the server.
  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The id of the most recently created job. Null until one is posted.
  int? lastCreatedJobId;

  /*
      Buy three days at the top of the feed.

      Separate from posting because it needs the job to exist first, and
      because it spends barya — a post that quietly charged for placement
      as a side effect of saving would be the one place in the app that
      takes credits without asking.
  */
  Future<bool> boostJob(int jobId) async {
    try {
      await _api.post('/jobs/$jobId/boost');
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> createJob({
    required String title,
    required String description,
    required int categoryId,
    List<int> skillIds = const [],
    double? budgetMin,
    double? budgetMax,
    String budgetPeriod = 'project',
    required String location,
    String? city,
    int? locationId,
    double? latitude,
    double? longitude,
    bool isUrgent = false,
    required List<File> photos,
    // Required by the server on new posts: a job with no date cannot be checked
    // against a worker's other commitments, so auto-withdraw-on-hire would
    // silently skip exactly the jobs that omitted it.
    required DateTime startDate,
    DateTime? endDate,
    String? startTime,
  }) async {
    _setLoading(true);
    try {
      final formData = FormData.fromMap({
        'title':               title,
        'description':         description,
        'category_id':         categoryId,
        'required_skill_ids':  skillIds,
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
        'budget_period':       budgetPeriod,
        'location':            location,
        if (city != null) 'city': city,
        // Structured location. Nullable so a job posted before the picker
        // existed still saves.
        if (locationId != null) 'location_id': locationId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        // Multipart stringifies every value, and FormData would send the Dart
        // bools as "true"/"false" — which Laravel's `boolean` rule rejects
        // (it only accepts 1/0/"1"/"0"), failing with "The urgent field must
        // be true or false." Send the numeric form instead.
        'is_urgent':     isUrgent ? '1' : '0',
        // Y-m-d only. Sending an ISO timestamp would make Laravel's
        // `after_or_equal:today` compare against midnight in the server's
        // timezone, so a job legitimately starting today would be rejected as
        // being in the past.
        'start_date': ymd(startDate),
        if (endDate != null) 'end_date': ymd(endDate),
        if (startTime != null) 'start_time': startTime,
        'photos': await Future.wait(photos.map(
          (f) => MultipartFile.fromFile(f.path, filename: f.path.split(Platform.pathSeparator).last),
        )),
        // multiCompatible appends `[]` to every list leaf — required so
        // Laravel actually parses `required_skill_ids`/`photos` as arrays.
        // Plain `multi` (the default) repeats the field name with no
        // brackets, which PHP collapses to just the last value.
      }, ListFormat.multiCompatible);

      final res = await _api.postMultipart('/jobs', formData);

      final job = res.data['data'] as Map<String, dynamic>;
      _jobs.insert(0, job);
      // Kept so the caller can boost the post it just made — the boost
      // endpoint needs an id, which only exists once the job is saved.
      lastCreatedJobId = job['id'] as int?;
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ── Update job ─────────────────────────────────────────────────────────────────

  Future<bool> updateJob(int jobId, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      final res = await _api.put('/jobs/$jobId', data: data);
      final updated = res.data['data'] as Map<String, dynamic>;
      final idx = _jobs.indexWhere((j) => j['id'] == jobId);
      if (idx != -1) _jobs[idx] = updated;
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ── Change status ──────────────────────────────────────────────────────────────

  /// The server's own wording for the last status change.
  ///
  /// Read once by the caller. Completion is two-sided, so "completed" can mean
  /// either "waiting for the worker" or "both confirmed", and only the server
  /// knows which.
  String? lastStatusMessage;

  /// Changes a job's status and adopts **the status the server actually set**.
  ///
  /// This used to write the requested status into the local list on success:
  ///
  ///     _jobs[idx]['status'] = status;
  ///
  /// which was fine while asking was the same as getting. It stopped being true
  /// when completion became two-sided — the request succeeds, the server
  /// records the employer's half and deliberately leaves the job `in_progress`,
  /// and the app then showed it as `completed` anyway. The job jumped to the
  /// Completed tab, the review button never appeared because the server still
  /// disagreed, and nothing on screen explained why.
  Future<bool> changeStatus(int jobId, String status) async {
    try {
      final res = await _api.patch('/jobs/$jobId/status', data: {'status': status});

      final body = res.data;
      lastStatusMessage = body is Map ? body['message'] as String? : null;

      final job = body is Map ? body['data'] : null;
      final actual = job is Map ? job['status'] as String? : null;

      final idx = _jobs.indexWhere((j) => j['id'] == jobId);
      if (idx != -1) {
        _jobs[idx]['status'] = actual ?? _jobs[idx]['status'];
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ── Delete job ─────────────────────────────────────────────────────────────────

  Future<bool> deleteJob(int jobId) async {
    try {
      await _api.delete('/jobs/$jobId');
      _jobs.removeWhere((j) => j['id'] == jobId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ── Single job (details screen) ─────────────────────────────────────────────

  bool _isDetailLoading = false;
  String? _detailError;
  Job? _selectedJob;

  bool get isDetailLoading => _isDetailLoading;
  String? get detailErrorMessage => _detailError;
  Job? get selectedJob => _selectedJob;

  /// GET /jobs/{id} — everything job_details_screen needs in one call,
  /// including this worker's match score, applied/saved state.
  Future<void> fetchJobDetail(int jobId) async {
    // Drop the previous job before loading a different one.
    //
    // Without this, opening job B renders job A — its title, its photos, its
    // pay — for as long as the request takes, then snaps to the real content.
    // That is the "the last screen flashes up first" effect: the detail screen
    // builds from whatever the provider is still holding.
    //
    // Guarded on the id so a pull-to-refresh or a retry of the *same* job
    // doesn't blank the screen the user is already reading.
    if (_selectedJob?.id != jobId) {
      _selectedJob = null;
    }

    _isDetailLoading = true;
    _detailError = null;
    notifyListeners();

    try {
      final res = await _api.get('/jobs/$jobId');
      _selectedJob = Job.fromApi(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      _detailError = e.toString().replaceFirst('Exception: ', '');
      _selectedJob = null;
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  // ── Saved jobs (worker side) ─────────────────────────────────────────────────

  // ── Saved jobs ──────────────────────────────────────────────────────────────

  bool _isSavedLoading = false;
  String? _savedError;
  List<Job> _savedJobs = [];

  bool get isSavedLoading => _isSavedLoading;
  String? get savedErrorMessage => _savedError;
  List<Job> get savedJobs => _savedJobs;

  /// GET /saved-jobs. The screen showed five hardcoded cards before this
  /// existed, so nothing a worker actually saved was ever displayed.
  Future<void> fetchSavedJobs() async {
    _isSavedLoading = true;
    _savedError = null;
    notifyListeners();

    try {
      final res = await _api.get('/saved-jobs');
      final rows = res.data['data'] as List;
      _savedJobs = rows.map((j) => Job.fromApi(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _savedError = e.toString().replaceFirst('Exception: ', '');
      _savedJobs = [];
    }

    _isSavedLoading = false;
    notifyListeners();
  }

  Future<bool> saveJob(int jobId) async {
    try {
      await _api.post('/jobs/$jobId/save');
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> unsaveJob(int jobId) async {
    try {
      await _api.delete('/jobs/$jobId/save');
      // Drop it locally too, so the saved list does not keep showing a job the
      // user just removed until the next full fetch.
      _savedJobs.removeWhere((j) => j.id == jobId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Unsaves everything currently in the list.
  ///
  /// There is no bulk endpoint, so this is one request per job. Any that fail
  /// stay saved and are reported, rather than being silently dropped from the
  /// list — the old "Clear All" showed a success toast and deleted nothing.
  Future<int> clearSavedJobs() async {
    final ids = _savedJobs.map((j) => j.id).toList();
    var removed = 0;

    for (final id in ids) {
      try {
        await _api.delete('/jobs/$id/save');
        removed++;
      } catch (_) {
        // Left in place; the refetch below will show it still saved.
      }
    }

    await fetchSavedJobs();
    return removed;
  }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
