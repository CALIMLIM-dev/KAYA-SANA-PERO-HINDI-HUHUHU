import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';

/// Manages employer-side job posting and management state.
class JobProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _jobs = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get jobs => _jobs;

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
    required String location,
    String? city,
    bool isUrgent = false,
    bool isNegotiable = false,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.post('/jobs', data: {
        'title':               title,
        'description':         description,
        'category_id':         categoryId,
        'required_skill_ids':  skillIds,
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
        'location':            location,
        if (city != null) 'city': city,
      });

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

  void clearError() { _errorMessage = null; notifyListeners(); }
}
