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

  Future<bool> accept(int applicationId) async {
    try {
      await _api.patch('/applications/$applicationId/accept');
      final idx = _applications.indexWhere((a) => a['id'] == applicationId);
      if (idx != -1) {
        _applications[idx]['status'] = 'accepted';
        notifyListeners();
      }
      return true;
    } catch (e) {
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
