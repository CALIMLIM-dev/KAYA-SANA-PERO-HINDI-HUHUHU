import 'package:flutter/foundation.dart';

import '../data/models/location_model.dart';
import '../data/services/api_client.dart';

/// Philippine location lookup for the picker.
///
/// Backed by our own PSGC table, so searches are fast and free — no third-party
/// geocoding call, no API key, no quota.
class LocationProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<LocationModel> _results = [];
  bool _isSearching = false;
  String? _errorMessage;

  /// Cache keyed by the search term, so re-typing or backspacing does not
  /// re-hit the network for a query already answered.
  final Map<String, List<LocationModel>> _cache = {};

  List<LocationModel> get results => _results;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  Future<void> search(String term) async {
    final key = term.trim().toLowerCase();

    if (_cache.containsKey(key)) {
      _results = _cache[key]!;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get(
        '/locations/search',
        queryParameters: {if (key.isNotEmpty) 'q': key, 'limit': 20},
      );

      final data = (response.data['data'] as List)
          .map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _cache[key] = data;
      _results = data;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _results = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Resolves a GPS fix to the nearest city/municipality, so "use my current
  /// location" yields a normalized place rather than raw coordinates.
  Future<LocationModel?> nearest(double lat, double lng) async {
    try {
      final response = await _api.get(
        '/locations/nearest',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      return LocationModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Rehydrates a stored location_id into a full record for display.
  Future<LocationModel?> byId(int id) async {
    try {
      final response = await _api.get('/locations/$id');
      return LocationModel.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _results = [];
    _errorMessage = null;
    notifyListeners();
  }
}
