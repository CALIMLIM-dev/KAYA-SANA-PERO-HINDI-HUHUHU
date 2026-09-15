import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/services/api_client.dart';

/*
    The community board: what is on it, what the caller has posted, and
    what a post costs.

    Posts are plain maps, the shape the server sends, because the board
    renders them and does nothing else with them. The one piece of state
    the screens need beyond the list is the price, fetched once so the
    compose screen can show it before anything is written.
*/
class CommunityProvider with ChangeNotifier {
  CommunityProvider([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _mine = const [];
  bool _loading = false;
  bool _hasLoaded = false;
  String? _error;

  /// all | worker | business
  String _type = 'all';

  int? _workerCost;
  int? _businessCost;
  int? _days;

  List<Map<String, dynamic>> get posts => _posts;
  List<Map<String, dynamic>> get mine => _mine;
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  String get type => _type;
  int? get workerCost => _workerCost;
  int? get businessCost => _businessCost;
  int? get days => _days;

  Future<void> setType(String type) async {
    if (_type == type) return;
    _type = type;
    notifyListeners();
    await load(force: true);
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_hasLoaded && !force) return;
    if (await ApiClient.getToken() == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final query = _type == 'all' ? '' : '?type=$_type';
      final res = await _api.get('/community$query');
      final data = res.data['data'];
      final rows = data is Map ? data['data'] : data;
      _posts = ((rows as List?) ?? []).cast<Map<String, dynamic>>();
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMine() async {
    if (await ApiClient.getToken() == null) return;
    try {
      final res = await _api.get('/community/mine');
      _mine = ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (_) {
      // The board list is the page; my posts are a section that can be empty.
    }
  }

  Future<void> loadCosts() async {
    if (_workerCost != null) return;
    if (await ApiClient.getToken() == null) return;
    try {
      final res = await _api.get('/community/costs');
      final data = res.data['data'] as Map<String, dynamic>;
      _workerCost = (data['worker'] as num?)?.toInt();
      _businessCost = (data['business'] as num?)?.toInt();
      _days = (data['days'] as num?)?.toInt();
      notifyListeners();
    } catch (_) {
      // The compose screen says "the price shows here" until it does.
    }
  }

  Future<Map<String, dynamic>?> fetchOne(int id) async {
    try {
      final res = await _api.get('/community/$id');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  /// Posts, and returns the new post or null with [error] set.
  Future<Map<String, dynamic>?> create({
    required String type,
    required String title,
    required String body,
    int? categoryId,
    String? location,
    int? locationId,
    XFile? photo,
  }) async {
    _error = null;
    try {
      final form = FormData.fromMap({
        'type': type,
        'title': title,
        'body': body,
        'category_id': ?categoryId,
        if (location != null && location.isNotEmpty) 'location': location,
        'location_id': ?locationId,
        if (photo != null)
          'photo': await MultipartFile.fromFile(photo.path, filename: photo.name),
      });
      final res = await _api.postMultipart('/community', form);
      final post = res.data['data'] as Map<String, dynamic>;
      _posts = [post, ..._posts];
      _mine = [post, ..._mine];
      notifyListeners();
      return post;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> takeDown(int id) async {
    try {
      await _api.delete('/community/$id');
      _posts = _posts.where((p) => p['id'] != id).toList();
      _mine = _mine
          .map((p) => p['id'] == id ? {...p, 'status': 'ended'} : p)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Opens the thread with the poster. Returns what the chat screen needs.
  Future<Map<String, dynamic>?> contact(int id) async {
    _error = null;
    try {
      final res = await _api.post('/community/$id/contact');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  @visibleForTesting
  void seedForTesting(List<Map<String, dynamic>> posts,
      {int workerCost = 5, int businessCost = 15, int days = 7}) {
    _posts = List.of(posts);
    _hasLoaded = true;
    _workerCost = workerCost;
    _businessCost = businessCost;
    _days = days;
    notifyListeners();
  }

  void clear() {
    _posts = const [];
    _mine = const [];
    _hasLoaded = false;
    _error = null;
    _type = 'all';
    notifyListeners();
  }
}
