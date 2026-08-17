import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../data/models/worker_skill_model.dart';
import '../data/models/worker_certification_model.dart';
import '../data/models/worker_license_model.dart';
import '../data/models/worker_experience_model.dart';
import '../data/models/category_model.dart';
import '../data/models/skill_model.dart';
import '../data/services/api_client.dart';

class WorkerProfileProvider with ChangeNotifier {
  final ApiClient _apiClient;

  WorkerProfileProvider(this._apiClient);

  List<WorkerSkillModel> _skills = [];
  List<WorkerCertificationModel> _certifications = [];
  List<WorkerLicenseModel> _licenses = [];
  List<WorkerExperienceModel> _experiences = [];
  List<Map<String, dynamic>> _licenseExaminations = [];
  List<CategoryModel> _categories = [];
  List<SkillModel> _availableSkills = [];

  bool _isLoading = false;
  String? _errorMessage;

  /// Guards the auto-fetch in main.dart's proxy provider, which re-runs on every
  /// AuthProvider notification. Without it the profile refetched continuously.
  bool _hasFetchedOnce = false;

  // Stub properties for compatibility with existing screens
  String? name;
  String? location;
  String? phone;
  String? email;
  String? profilePhotoPath;
  List<Map<String, String>> experiences = [];

  List<WorkerSkillModel> get skills => _skills;
  List<WorkerCertificationModel> get certifications => _certifications;
  List<WorkerLicenseModel> get licenses => _licenses;
  List<WorkerExperienceModel> get experiencesNew => _experiences;
  List<Map<String, dynamic>> get licenseExaminations => _licenseExaminations;
  List<CategoryModel> get categories => _categories;
  List<SkillModel> get availableSkills => _availableSkills;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasFetchedOnce => _hasFetchedOnce;

  // Stub methods for compatibility
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    _hasFetchedOnce = true;
    notifyListeners();

    try {
      // Fetch user basic info
      final userResponse = await _apiClient.get('/user');
      if (userResponse.data != null && userResponse.data['success'] == true) {
        final userData = userResponse.data['data'];
        name = userData['name'];
        email = userData['email'];
        phone = userData['phone'];
        location = userData['city']; // Backend uses 'city' column
        profilePhotoPath = userData['avatar'];
      }
      
      // Fetch all the profile data types (don't fail if one fails)
      await Future.wait([
        fetchSkills().catchError((e) => null),
        fetchCertifications().catchError((e) => null),
        fetchLicenses().catchError((e) => null),
        fetchExperiences().catchError((e) => null),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
      // Don't rethrow - just log the error
      print('Error fetching profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadPhoto({bool fromCamera = false}) async {
    try {
      // Use image_picker package to pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return false;
      
      // Create multipart request
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });
      
      final response = await _apiClient.post('/worker/profile/photo', data: formData);
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        profilePhotoPath = data['data']['photo_path'];
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateName(String newName) async {
    try {
      final response = await _apiClient.put('/worker/profile', data: {'name': newName});
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        name = newName;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateLocation(String newLocation) async {
    try {
      final response = await _apiClient.put('/worker/profile', data: {'city': newLocation});
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        location = newLocation;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> completeSetup() async {
    try {
      final response = await _apiClient.post('/worker/profile/complete-setup');
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteProfile() async {
    try {
      final response = await _apiClient.delete('/worker/profile');
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        // Clear local state
        location = null;
        phone = null;
        _skills = [];
        _certifications = [];
        _licenses = [];
        _licenseExaminations = [];
        _experiences = [];
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updatePhone(String newPhone) async {
    try {
      final response = await _apiClient.put('/worker/profile', data: {'phone': newPhone});
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        phone = newPhone;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<void> saveSkillsWithCategories(List<SkillModel> selectedSkills) async {
    try {
      // Delete all existing skills
      for (var skill in _skills) {
        await deleteSkill(skill.id!);
      }
      
      // Add new skills with category and skill IDs
      for (var skillModel in selectedSkills) {
        final skill = WorkerSkillModel(
          userId: 0, // Set by backend
          skillName: skillModel.name,
          proficiencyLevel: 'intermediate',
          yearsOfExperience: 1,
          categoryId: skillModel.categoryId,
          skillId: skillModel.id,
        );
        await addSkill(skill);
      }
      
      // Refresh the list
      await fetchSkills();
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
    }
  }

  Future<void> saveSkillsLocal(List<String> skillNames) async {
    try {
      // Remove duplicates
      final uniqueSkillNames = skillNames.toSet().toList();
      
      // Delete all existing skills
      for (var skill in _skills) {
        await deleteSkill(skill.id!);
      }
      
      // Add new skills with default values (backwards compatibility)
      for (var skillName in uniqueSkillNames) {
        final skill = WorkerSkillModel(
          userId: 0, // Set by backend
          skillName: skillName,
          proficiencyLevel: 'intermediate',
          yearsOfExperience: 1,
        );
        await addSkill(skill);
      }
      
      // Refresh the list
      await fetchSkills();
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
    }
  }

  // ==================== CATEGORIES ====================
  
  Future<void> fetchCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/categories');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _categories = (data['data'] as List)
            .map((json) => CategoryModel.fromJson(json))
            .toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CategoryModel?> createCustomCategory(String categoryName) async {
    try {
      final response = await _apiClient.post('/categories', data: {'name': categoryName});
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        final newCategory = CategoryModel.fromJson(data['data']);
        _categories.add(newCategory);
        notifyListeners();
        return newCategory;
      } else {
        _errorMessage = _extractErrorMessage(data['message']);
        return null;
      }
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      return null;
    }
  }

  /// Guards against a stale response clobbering a newer one. Switching
  /// category quickly (A, then B before A's request lands) has no ordering
  /// guarantee — if A's response arrives after B's, `_availableSkills` was
  /// silently overwritten with the wrong category's skills, which is exactly
  /// what showed up as "random" skills on the job-posting form.
  int _skillsRequestId = 0;

  Future<void> fetchSkillsByCategory(int categoryId) async {
    final requestId = ++_skillsRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/skills?category_id=$categoryId');
      if (requestId != _skillsRequestId) return; // superseded by a newer request

      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _availableSkills = (data['data'] as List)
            .map((json) => SkillModel.fromJson(json))
            .toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      if (requestId != _skillsRequestId) return;
      _errorMessage = e.toString();
    } finally {
      if (requestId == _skillsRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<SkillModel?> createCustomSkill(String skillName, int categoryId) async {
    try {
      final response = await _apiClient.post('/skills', data: {
        'name': skillName,
        'category_id': categoryId,
      });
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        final newSkill = SkillModel.fromJson(data['data']);
        // Don't replace the list, just add to it
        if (!_availableSkills.any((s) => s.id == newSkill.id)) {
          _availableSkills.add(newSkill);
        }
        notifyListeners();
        return newSkill;
      } else {
        _errorMessage = _extractErrorMessage(data['message']);
        return null;
      }
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      return null;
    }
  }

  // Helper to extract clean error messages
  String _extractErrorMessage(String rawMessage) {
    // Remove exception type prefixes
    final patterns = [
      'Exception: ',
      'DioException: ',
      'DioError: ',
      'Error: ',
      'type \'',
      '\' is not a subtype of',
    ];
    
    String cleaned = rawMessage;
    for (var pattern in patterns) {
      if (cleaned.contains(pattern)) {
        cleaned = cleaned.split(pattern).first;
      }
    }
    
    // If message is still technical, return generic message
    if (cleaned.contains('DioException') || 
        cleaned.contains('SocketException') || 
        cleaned.contains('FormatException') ||
        cleaned.length > 100) {
      return 'Something went wrong. Please try again.';
    }
    
    return cleaned.trim();
  }


  Future<bool> createCertification(Map<String, dynamic> certData) async {
    // Stub - for backward compatibility with old screens
    return true;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== SKILLS ====================
  
  Future<void> fetchSkills() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/worker/skills');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _skills = (data['data'] as List)
            .map((json) => WorkerSkillModel.fromJson(json))
            .toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSkill(WorkerSkillModel skill) async {
    try {
      final response = await _apiClient.post('/worker/skills', data: skill.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchSkills();
        return true;
      } else {
        _errorMessage = _extractErrorMessage(data['message']);
        return false;
      }
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      return false;
    }
  }

  Future<bool> updateSkill(int id, WorkerSkillModel skill) async {
    try {
      final response = await _apiClient.put('/worker/skills/$id', data: skill.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchSkills();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteSkill(int id) async {
    try {
      final response = await _apiClient.delete('/worker/skills/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchSkills();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // ==================== CERTIFICATIONS ====================
  
  Future<void> fetchCertifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/worker/certifications');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _certifications = (data['data'] as List)
            .map((json) => WorkerCertificationModel.fromJson(json))
            .toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCertification(WorkerCertificationModel certification, {String? filePath}) async {
    try {
      final Map<String, dynamic> formDataMap = {
        'certification_name': certification.certificationName,
        'issuing_organization': certification.issuingOrganization,
        if (certification.issueDate != null) 
          'issue_date': certification.issueDate!.toIso8601String().split('T')[0],
        if (certification.expiryDate != null)
          'expiry_date': certification.expiryDate!.toIso8601String().split('T')[0],
        if (certification.credentialId != null && certification.credentialId!.isNotEmpty)
          'credential_id': certification.credentialId!,
      };
      
      if (filePath != null) {
        formDataMap['document'] = await MultipartFile.fromFile(filePath, filename: 'certificate.jpg');
      }
      
      final formData = FormData.fromMap(formDataMap);
      
      final response = await _apiClient.postMultipart('/worker/certifications', formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchCertifications();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateCertification(int id, WorkerCertificationModel certification) async {
    try {
      final response = await _apiClient.put('/worker/certifications/$id', data: certification.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchCertifications();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteCertification(int id) async {
    try {
      final response = await _apiClient.delete('/worker/certifications/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchCertifications();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // ==================== LICENSES ====================
  
  Future<void> fetchLicenses() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/worker/licenses');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _licenses = (data['data'] as List)
            .map((json) => WorkerLicenseModel.fromJson(json))
            .toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addLicense(WorkerLicenseModel license, {String? filePath}) async {
    try {
      final Map<String, dynamic> formDataMap = {
        'license_name': license.licenseName,
        'license_number': license.licenseNumber,
        'issuing_authority': license.issuingAuthority,
        if (license.issueDate != null) 
          'issue_date': license.issueDate!.toIso8601String().split('T')[0],
        if (license.expiryDate != null)
          'expiry_date': license.expiryDate!.toIso8601String().split('T')[0],
      };
      
      if (filePath != null) {
        formDataMap['document'] = await MultipartFile.fromFile(filePath, filename: 'license.jpg');
      }
      
      final formData = FormData.fromMap(formDataMap);
      
      final response = await _apiClient.postMultipart('/worker/licenses', formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenses();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateLicense(int id, WorkerLicenseModel license) async {
    try {
      final response = await _apiClient.put('/worker/licenses/$id', data: license.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenses();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteLicense(int id) async {
    try {
      final response = await _apiClient.delete('/worker/licenses/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenses();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // ==================== EXPERIENCES ====================
  
  Future<void> fetchExperiences() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/worker/experiences');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _experiences = (data['data'] as List)
            .map((json) => WorkerExperienceModel.fromJson(json))
            .toList();
        
        // Update old experiences list for backward compatibility
        experiences = _experiences.map((exp) => {
          'id': exp.id.toString(),
          'title': exp.jobTitle,
          'company': exp.companyName,
          'start_date': exp.startDate,
          'end_date': exp.endDate ?? '',
          'description': exp.description ?? '',
        }).toList();
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createExperience(Map<String, dynamic> expData) async {
    try {
      // Convert from form format (M/YYYY) to database format (YYYY-MM-01)
      final startParts = (expData['startDate'] as String).split('/');
      final startDate = '${startParts[1]}-${startParts[0].padLeft(2, '0')}-01';
      
      String? endDate;
      if (expData['endDate'] != 'Present') {
        final endParts = (expData['endDate'] as String).split('/');
        endDate = '${endParts[1]}-${endParts[0].padLeft(2, '0')}-01';
      }
      
      final experience = WorkerExperienceModel(
        jobTitle: expData['jobTitle'] as String,
        companyName: expData['company'] as String,
        description: expData['description'] as String?,
        startDate: startDate,
        endDate: endDate,
        isCurrent: expData['endDate'] == 'Present',
      );
      
      final response = await _apiClient.post('/worker/experiences', data: experience.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchExperiences();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateExperience(int id, Map<String, dynamic> expData) async {
    try {
      // Convert from form format (M/YYYY) to database format (YYYY-MM-01)
      final startParts = (expData['startDate'] as String).split('/');
      final startDate = '${startParts[1]}-${startParts[0].padLeft(2, '0')}-01';
      
      String? endDate;
      if (expData['endDate'] != 'Present') {
        final endParts = (expData['endDate'] as String).split('/');
        endDate = '${endParts[1]}-${endParts[0].padLeft(2, '0')}-01';
      }
      
      final experience = WorkerExperienceModel(
        jobTitle: expData['jobTitle'] as String,
        companyName: expData['company'] as String,
        description: expData['description'] as String?,
        startDate: startDate,
        endDate: endDate,
        isCurrent: expData['endDate'] == 'Present',
      );
      
      final response = await _apiClient.put('/worker/experiences/$id', data: experience.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchExperiences();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteExperience(int id) async {
    try {
      final response = await _apiClient.delete('/worker/experiences/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchExperiences();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }
  
  // ==================== LICENSE EXAMINATIONS ====================
  
  Future<void> fetchLicenseExaminations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/worker/license-examinations');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        _licenseExaminations = List<Map<String, dynamic>>.from(data['data']);
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addLicenseExamination(Map<String, dynamic> examination) async {
    try {
      final response = await _apiClient.post('/worker/license-examinations', data: examination);
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenseExaminations();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> updateLicenseExamination(int id, Map<String, dynamic> examination) async {
    try {
      final response = await _apiClient.put('/worker/license-examinations/$id', data: examination);
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenseExaminations();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> deleteLicenseExamination(int id) async {
    try {
      final response = await _apiClient.delete('/worker/license-examinations/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success']) {
        await fetchLicenseExaminations();
        return true;
      } else {
        _errorMessage = data['message'];
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }
}
