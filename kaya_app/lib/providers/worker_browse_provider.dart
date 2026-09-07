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

  /*
      The most hired workers in a place, for the home screen's second row.

      Kept apart from [workers] on purpose: that list is whatever the employer
      last searched or filtered for, and a recommendation row that changes
      whenever somebody types in the search box is not a recommendation. Same
      endpoint, different question - sort=jobs, which the server answers from
      completed applications.
  */
  List<WorkerProfile> _mostHired = [];
  List<WorkerProfile> get mostHired => _mostHired;

  /*
      Fills both lists for a test, which has no server to fetch from.

      The home rows render nothing when their list is empty, so an overflow
      test against an unseeded provider lays out a blank strip and passes -
      which is the false pass that hid the profile header bug for weeks. This
      is how a test puts real cards in them.
  */
  @visibleForTesting
  void seedWorkers({List<WorkerProfile>? directory, List<WorkerProfile>? hired}) {
    if (directory != null) _workers = directory;
    if (hired != null) _mostHired = hired;
    notifyListeners();
  }
  Future<void> fetchMostHired({int? locationId, int limit = 10}) async {
    try {
      final res = await _api.get('/workers', queryParameters: {
        if (locationId != null) 'location_id': locationId,
        'sort': 'jobs',
        'per_page': limit,
      });

      final page = res.data['data'] as Map<String, dynamic>;

      _mostHired = (page['data'] as List)
          .map((w) => WorkerProfile.fromApi(w as Map<String, dynamic>))
          // Nobody with an empty record belongs in a row headed "most hired".
          .where((w) => w.completedJobs > 0)
          .toList();
    } catch (_) {
      // A recommendation row is not worth an error state, and a failed
      // refresh is not an empty row: whatever was last fetched stays.
    }

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
    /// Which order the server should rank in: best, rating, jobs,
    /// nearest or newest. Null leaves it to the server, which ranks
    /// best-first.
    String? sort,
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
        if (sort != null) 'sort': sort,
      });

      final page = res.data['data'] as Map<String, dynamic>;
      final rows = page['data'] as List;
      _workers = rows
          .map((w) => WorkerProfile.fromApi(w as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Same rule as the job feed: a failed refresh is not an empty
      // directory, and blanking it loses what the employer was reading.
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }
}
