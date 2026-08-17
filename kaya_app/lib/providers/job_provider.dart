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

  // ── Public job feed (worker-mode home + search) ─────────────────────────────

  bool _isPublicLoading = false;
  String? _publicError;
  List<Job> _publicJobs = [];

  bool get isPublicLoading => _isPublicLoading;
  String? get publicErrorMessage => _publicError;
  List<Job> get publicJobs => _publicJobs;

  /// GET /jobs — the feed the mock _getMockJobs() in unified_home_screen and
  /// search_screen used to stand in for. Includes a per-job match_score when
  /// the signed-in account has a worker profile (see JobMatchService).
  Future<void> fetchPublicJobs({
    String? search,
    int? categoryId,
    String? location,
    List<int>? skillIds,
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
    bool isNegotiable = false,
    required List<File> photos,
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
        'is_negotiable': isNegotiable ? '1' : '0',
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

  Future<bool> changeStatus(int jobId, String status) async {
    try {
      await _api.patch('/jobs/$jobId/status', data: {'status': status});
      final idx = _jobs.indexWhere((j) => j['id'] == jobId);
      if (idx != -1) { _jobs[idx]['status'] = status; notifyListeners(); }
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
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
