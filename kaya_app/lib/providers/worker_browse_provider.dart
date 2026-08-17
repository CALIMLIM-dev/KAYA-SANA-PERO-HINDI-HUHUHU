import 'package:flutter/foundation.dart';

import '../data/models/worker_profile_model.dart';
import '../data/services/api_client.dart';

/// The employer-facing worker directory — GET /workers.
///
/// Deliberately separate from WorkerProfileProvider, which manages the
/// signed-in worker's OWN profile (skills, certs, licenses). This is read-only
/// browsing of OTHER workers, the data behind the employer-mode home feed and
/// the Workers tab in search. It replaced the hardcoded `_getMockWorkers()` in
/// unified_home_screen and the equally hardcoded worker cards in search_screen.
class WorkerBrowseProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isLoading = false;
  String? _errorMessage;
  List<WorkerProfile> _workers = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<WorkerProfile> get workers => _workers;

  // ── Single worker (public profile screen) ───────────────────────────────────

  bool _isDetailLoading = false;
  String? _detailError;
  Map<String, dynamic>? _selectedWorker;

  bool get isDetailLoading => _isDetailLoading;
  String? get detailErrorMessage => _detailError;
  Map<String, dynamic>? get selectedWorker => _selectedWorker;

  /// GET /workers/{id} — full profile including experience, certifications and
  /// reviews, which the directory-list endpoint deliberately omits to keep
  /// that query cheap. Kept as a raw map rather than WorkerProfile because it
  /// carries fields (experiences, certifications, reviews) that model doesn't.
  /// Which worker [_selectedWorker] holds. Without it, opening a second
  /// worker's profile shows the first one's name, photo and skills until the
  /// request lands — the "previous screen flashes up" effect.
  int? _selectedWorkerId;

  Future<void> fetchWorkerDetail(int userId) async {
    if (_selectedWorkerId != userId) {
      _selectedWorker = null;
      _selectedWorkerId = userId;
    }

    _isDetailLoading = true;
    _detailError = null;
    notifyListeners();

    try {
      final res = await _api.get('/workers/$userId');
      _selectedWorker = res.data['data'] as Map<String, dynamic>;
    } catch (e) {
      _detailError = e.toString().replaceFirst('Exception: ', '');
      _selectedWorker = null;
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  Future<void> fetchWorkers({
    String? q,
    int? categoryId,
    int? skillId,
    int? locationId,
    // Pay and distance are filtered by the server: a worker with no rate on
    // file cannot honestly be claimed to fall inside a range, and a radius
    // cannot include someone whose position is unknown.
    double? rateMin,
    double? rateMax,
    String? rateUnit,
    double? radiusKm,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/workers', queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoryId != null) 'category_id': categoryId,
        if (skillId != null) 'skill_id': skillId,
        if (locationId != null) 'location_id': locationId,
        if (rateMin != null) 'rate_min': rateMin,
        if (rateMax != null) 'rate_max': rateMax,
        if (rateUnit != null) 'rate_unit': rateUnit,
        if (radiusKm != null) 'radius_km': radiusKm,
      });

      final page = res.data['data'] as Map<String, dynamic>;
      final rows = page['data'] as List;
      _workers = rows
          .map((w) => WorkerProfile.fromApi(w as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _workers = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}
