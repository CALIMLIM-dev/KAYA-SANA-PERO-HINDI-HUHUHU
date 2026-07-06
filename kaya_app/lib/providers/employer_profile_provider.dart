import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/employer_type.dart';
import '../data/models/employer_profile_model.dart';
import '../data/models/employer_verification_model.dart';
import '../data/services/api_client.dart';

/// Error types for better error handling
enum ProfileErrorType {
  network,
  unauthorized,
  notFound,
  validation,
  serverError,
  unknown,
}

class ProfileError {
  final ProfileErrorType type;
  final String message;
  final Map<String, dynamic>? details;

  ProfileError(this.type, this.message, [this.details]);

  @override
  String toString() => message;
}

class EmployerProfileProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  ProfileError? _error;
  bool _hasFetchedOnce = false;

  // Immutable models instead of individual fields
  EmployerProfile? _profile;
  EmployerVerification? _verification;

  bool get isLoading => _isLoading;
  ProfileError? get error => _error;
  String? get errorMessage => _error?.message;
  
  // Expose models, not individual fields
  EmployerProfile? get profile => _profile;
  EmployerVerification? get verification => _verification;
  
  // Convenience getters
  bool get hasProfile => _profile != null;
  bool get hasImage => _profile?.imageUrl != null;
  bool get hasFetchedOnce => _hasFetchedOnce;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  ProfileError _parseError(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ProfileError(
            ProfileErrorType.network,
            'Connection timeout. Please check your internet connection.',
          );
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final message = e.response?.data?['message'] as String?;
          
          switch (statusCode) {
            case 401:
              return ProfileError(
                ProfileErrorType.unauthorized,
                message ?? 'Unauthorized. Please log in again.',
              );
            case 403:
              return ProfileError(
                ProfileErrorType.unauthorized,
                message ?? 'Access forbidden.',
              );
            case 404:
              return ProfileError(
                ProfileErrorType.notFound,
                message ?? 'Profile not found.',
              );
            case 422:
              final errors = e.response?.data?['errors'] as Map<String, dynamic>?;
              return ProfileError(
                ProfileErrorType.validation,
                message ?? 'Validation error.',
                errors,
              );
            case 500:
            case 502:
            case 503:
              return ProfileError(
                ProfileErrorType.serverError,
                message ?? 'Server error. Please try again later.',
              );
            default:
              return ProfileError(
                ProfileErrorType.unknown,
                message ?? 'An error occurred.',
              );
          }
        default:
          return ProfileError(
            ProfileErrorType.network,
            'Network error. Please check your connection.',
          );
      }
    }
    
    return ProfileError(
      ProfileErrorType.unknown,
      e.toString().replaceFirst('Exception: ', ''),
    );
  }

  /// Fetch employer profile and verification status
  /// Returns 200 with profile: null if profile doesn't exist (not 404)
  /// Safe to call multiple times - prevents duplicate requests
  Future<void> fetchProfile() async {
    // Prevent duplicate fetches while already loading
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      final res = await _api.get('/employer-profile');
      final data = res.data['data'] as Map<String, dynamic>;
      
      // Parse profile (can be null)
      final profileData = data['profile'];
      _profile = profileData != null 
          ? EmployerProfile.fromJson(profileData as Map<String, dynamic>)
          : null;
      
      // Parse verification (always present)
      final verificationData = data['verification'] as Map<String, dynamic>;
      _verification = EmployerVerification.fromJson(verificationData);
      
      _error = null;
      _hasFetchedOnce = true;
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Create employer profile (first-time setup)
  /// Returns created profile directly from response (no nested fetch)
  Future<bool> createProfile({
    required EmployerType employerType,
    String? companyName,
    String? industry,
    String? website,
    String? description,
    required String location,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.post('/employer-profile', data: {
        'employer_type': employerType.value,
        if (companyName != null) 'company_name': companyName,
        if (industry != null) 'industry': industry,
        if (website != null) 'website': website,
        if (description != null) 'description': description,
        'location': location,
      });
      
      final data = res.data['data'] as Map<String, dynamic>;
      
      // Update state directly from response (no nested fetch)
      _profile = EmployerProfile.fromJson(data['profile'] as Map<String, dynamic>);
      _verification = EmployerVerification.fromJson(data['verification'] as Map<String, dynamic>);
      
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  /// Update employer profile with type-specific validation
  Future<bool> updateProfile({
    String? companyName,
    String? industry,
    String? website,
    String? description,
    String? location,
  }) async {
    if (_profile == null) {
      _error = ProfileError(
        ProfileErrorType.notFound,
        'No profile to update. Create profile first.',
      );
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final res = await _api.put('/employer-profile', data: {
        if (companyName != null) 'company_name': companyName,
        if (industry != null) 'industry': industry,
        if (website != null) 'website': website,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
      });
      
      final data = res.data['data'] as Map<String, dynamic>;
      
      // Update state from response
      _profile = EmployerProfile.fromJson(data['profile'] as Map<String, dynamic>);
      _verification = EmployerVerification.fromJson(data['verification'] as Map<String, dynamic>);
      
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  /// Upload employer image (company logo or individual photo)
  /// Returns full profile to maintain consistent response shape
  Future<bool> uploadImage({bool fromCamera = false}) async {
    if (_profile == null) {
      _error = ProfileError(
        ProfileErrorType.notFound,
        'Create profile first before uploading image.',
      );
      notifyListeners();
      return false;
    }

    try {
      XFile? file;
      if (kIsWeb) {
        file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      } else {
        file = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 80,
        );
      }
      if (file == null) return false;

      _setLoading(true);
      
      MultipartFile multipart;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        multipart = MultipartFile.fromBytes(bytes, filename: 'image.jpg');
      } else {
        multipart = await MultipartFile.fromFile(file.path, filename: 'image.jpg');
      }
      
      final formData = FormData.fromMap({'image': multipart});
      final res = await _api.postMultipart('/employer-profile/image', formData);
      
      final data = res.data['data'] as Map<String, dynamic>;
      
      // Update state from consistent response shape
      _profile = EmployerProfile.fromJson(data['profile'] as Map<String, dynamic>);
      _verification = EmployerVerification.fromJson(data['verification'] as Map<String, dynamic>);
      
      _error = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
