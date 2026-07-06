import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../data/services/api_client.dart';

class EmployerProfileProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;

  String? companyName;
  String? description;
  String? location;
  String? logoPath;
  String? employerType; // 'company' | 'individual'
  String verificationStatus = 'unverified';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLogo => logoPath != null;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }

  Future<void> fetchProfile() async {
    _setLoading(true);
    try {
      final res = await _api.get('/employer-profile');
      final data = res.data['data'] as Map<String, dynamic>;
      companyName        = data['company_name']    as String?;
      description        = data['description']     as String?;
      location           = data['location']        as String?;
      logoPath           = data['logo_path']       as String?;
      employerType       = data['employer_type']   as String?;
      verificationStatus = data['verification_status'] as String? ?? 'unverified';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({String? name, String? desc, String? loc, String? type}) async {
    _setLoading(true);
    try {
      final res = await _api.put('/employer-profile', data: {
        if (name != null) 'company_name':  name,
        if (desc != null) 'description':   desc,
        if (loc  != null) 'location':      loc,
        if (type != null) 'employer_type': type,
      });
      final data = res.data['data'];
      companyName  = data['company_name']  as String?;
      description  = data['description']   as String?;
      location     = data['location']      as String?;
      employerType = data['employer_type'] as String?;
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadLogo({bool fromCamera = false}) async {
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
        multipart = MultipartFile.fromBytes(bytes, filename: 'logo.jpg');
      } else {
        multipart = await MultipartFile.fromFile(file.path, filename: 'logo.jpg');
      }
      final formData = FormData.fromMap({'logo': multipart});
      final res = await _api.postMultipart('/employer-profile/logo', formData);
      logoPath = res.data['data']['logo_path'] as String?;
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void setNameLocal(String v)        { companyName = v;   notifyListeners(); }
  void setDescriptionLocal(String v) { description = v;   notifyListeners(); }
  void setLocationLocal(String v)    { location    = v;   notifyListeners(); }
  void setEmployerTypeLocal(String v){ employerType = v;  notifyListeners(); }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
