import 'package:flutter/foundation.dart';

import '../data/services/api_client.dart';

/// Reviews left after a completed job.
///
/// The server only accepts a review when the reviewer and reviewee were the two
/// actual parties on a *completed* job (employer ↔ hired worker), so a 403/422
/// here is expected and must be shown to the user rather than swallowed.
class ReviewProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<bool> submitReview({
    required int revieweeId,
    required int jobId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/reviews', data: {
        'reviewee_id': revieweeId,
        'job_id': jobId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
        // Omitted rather than sent empty, so a review with no chips picked
        // reads as "never asked" rather than "nothing stood out".
        if (tags.isNotEmpty) 'tags': tags,
      });

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }
}
