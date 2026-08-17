import 'package:flutter/foundation.dart';
import '../data/services/api_client.dart';

/// How many people looked at your profile recently.
///
/// Deliberately its own provider rather than a field on the profile providers:
/// the count is read on the profile screen and nowhere else, and folding it
/// into `/me` would make every app launch pay for two extra queries to render
/// a line most screens never show.
class ProfileViewProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  int _workerUniqueViewers = 0;
  int _employerUniqueViewers = 0;
  int _days = 7;

  bool _isLoading = false;
  String? _errorMessage;

  /// Distinct people who opened your worker profile in the window.
  int get workerUniqueViewers => _workerUniqueViewers;

  /// The same for your company page, counted separately — a hybrid account's
  /// worker figure must not include people reading their employer profile.
  int get employerUniqueViewers => _employerUniqueViewers;

  int get days => _days;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True once a successful fetch has happened.
  ///
  /// Zero viewers and "not loaded yet" both read as 0, and showing "0 viewers"
  /// to someone whose request simply failed is worse than showing nothing.
  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  Future<void> fetch({int days = 7}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get(
        '/profile-views/summary',
        queryParameters: {'days': days},
      );

      final data = res.data['data'] as Map<String, dynamic>;
      _days = (data['days'] as num?)?.toInt() ?? days;
      _workerUniqueViewers =
          ((data['worker'] as Map?)?['unique_viewers'] as num?)?.toInt() ?? 0;
      _employerUniqueViewers =
          ((data['employer'] as Map?)?['unique_viewers'] as num?)?.toInt() ?? 0;
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cleared on logout so the next account never sees the previous one's count.
  void clear() {
    _workerUniqueViewers = 0;
    _employerUniqueViewers = 0;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
