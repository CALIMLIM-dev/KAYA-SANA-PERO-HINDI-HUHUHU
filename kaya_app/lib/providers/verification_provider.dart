import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../data/services/api_client.dart';

class VerificationProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _verifications = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get verifications => _verifications;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }

  /// Fetch user's verification statuses
  Future<void> fetchVerifications() async {
    _setLoading(true);
    try {
      final res = await _api.get('/verifications');
      _verifications = (res.data['data'] as List).cast<Map<String, dynamic>>();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  /// Get status for a specific type
  String statusFor(String type) {
    final match = _verifications.where((v) => v['document_type'] == type).toList();
    if (match.isEmpty) return 'unverified';
    return match.first['status'] as String? ?? 'unverified';
  }

  bool isVerified(String type) => statusFor(type) == 'verified';
  bool isPending(String type) => statusFor(type) == 'pending';

  /// Submit Government ID verification with both ID photo and selfie
  Future<bool> submitGovernmentID({
    required String idType,
    required String idPhotoPath,
    required String selfiePhotoPath,
  }) async {
    _setLoading(true);
    try {
      final formData = FormData.fromMap({
        'type': 'government_id',
        'id_type': idType,
        'id_photo': await MultipartFile.fromFile(idPhotoPath, filename: 'id_photo.jpg'),
        'selfie_photo': await MultipartFile.fromFile(selfiePhotoPath, filename: 'selfie.jpg'),
      });
      
      await _api.postMultipart('/verifications', formData);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Submit a verification document — handles both web (bytes) and mobile (path)
  Future<bool> submitDocument({
    required String type,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    _setLoading(true);
    try {
      MultipartFile multipart;
      if (kIsWeb && fileBytes != null) {
        multipart = MultipartFile.fromBytes(fileBytes, filename: fileName);
      } else if (filePath != null) {
        multipart = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        _errorMessage = 'No file selected';
        _setLoading(false);
        return false;
      }

      final formData = FormData.fromMap({
        'type': type,
        'document': multipart,
      });
      await _api.postMultipart('/verifications', formData);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Pick a document — returns path (mobile) or bytes (web)
  Future<Map<String, dynamic>?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb, // load bytes on web
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;

    if (kIsWeb) {
      if (file.bytes == null) return null;
      return {
        'name': file.name,
        'bytes': file.bytes!.toList(),
      };
    } else {
      if (file.path == null) return null;
      return {
        'name': file.name,
        'path': file.path!,
      };
    }
  }

  /// Capture photo from camera (for Government ID and Selfie)
  Future<Map<String, dynamic>?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (photo == null) return null;
      
      return {
        'name': photo.name,
        'path': photo.path,
      };
    } catch (e) {
      _errorMessage = 'Camera access denied or unavailable';
      notifyListeners();
      return null;
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
