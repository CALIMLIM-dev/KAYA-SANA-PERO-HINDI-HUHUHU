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

  /*
      The pinned spot, kept rather than only sent.

      These were write-only: updateLocation posted them and nothing ever read
      them back, so the app had no way to tell an account that had pinned its
      exact position from one sitting on a city centroid. The profile needs to
      know, because pinning is what makes every distance on every job card
      real rather than "somewhere in this city".
  */
  double? latitude;
  double? longitude;

  /// True once an exact position has been dropped, not just a city chosen.
  bool get hasPinnedLocation => latitude != null && longitude != null;
  String? phone;
  String? email;
  String? profilePhotoPath;

  /*
      The resume on file, if any.

      Only the name and the date. The path is never sent to the client: a
      resume carries a phone number, a home address and an employment history,
      and the server hands it out through a gated download rather than as a
      URL anyone who sees it can keep.
  */
  bool hasResume = false;
  String? resumeFileName;
  DateTime? resumeUploadedAt;
  List<Map<String, String>> experiences = [];

  List<WorkerSkillModel> get skills => _skills;

  /// Lets a test render the profile with skills on it.
  ///
  /// The header groups these by category and draws a chip per skill, so a
  /// profile with none renders a shorter header than any real one - which is
  /// how a header that overflowed by eleven pixels passed every test.
  @visibleForTesting
  void seedSkills(List<WorkerSkillModel> skills) {
    _skills = skills;
    notifyListeners();
  }
  List<WorkerCertificationModel> get certifications => _certifications;
  List<WorkerLicenseModel> get licenses => _licenses;
  List<WorkerExperienceModel> get experiencesNew => _experiences;
  List<Map<String, dynamic>> get licenseExaminations => _licenseExaminations;
  List<CategoryModel> get categories => _categories;

  /// Lets a test render the home screen with real category tiles in it.
  ///
  /// The tiles are fixed-width and their labels are not, so they only break on
  /// a long category name - which an empty provider never produces.
  @visibleForTesting
  void seedCategories(List<CategoryModel> categories) {
    _categories = categories;
    _categoriesLoaded = true;
    notifyListeners();
  }
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

      /*
          Checked as a Map before it is indexed like one.

          `response.data['success']` assumed JSON. When the body is a String —
          a 502 HTML error page, a login redirect, a connection cut mid-request
          — indexing it throws "type 'String' is not a subtype of type 'int' of
          'index'", which is thrown from deep inside Dart and names neither the
          request nor the screen. That message has been appearing on every test
          run of this project, and it would appear in production the first time
          the tunnel hiccuped, as a profile that silently failed to load.
      */
      final body = userResponse.data;
      final userData = body is Map ? body['data'] : null;

      if (body is Map && body['success'] == true && userData is Map) {
        name = userData['name'] as String?;
        email = userData['email'] as String?;
        phone = userData['phone'] as String?;
        location = userData['city'] as String?; // Backend uses 'city' column
        latitude = (userData['latitude'] as num?)?.toDouble();
        longitude = (userData['longitude'] as num?)?.toDouble();
        profilePhotoPath = userData['avatar'] as String?;

        // Name and date only - the path never leaves the server.
        _adoptResume(userData['resume']);
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
      debugPrint('[worker profile] fetch failed: $e');
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

  /// [locationId] is the PSGC row id from the picker. Passing only the display
  /// string leaves the profile without coordinates, which silently disables
  /// every distance and proximity feature for that worker.
  Future<bool> updateLocation(
    String newLocation, {
    int? locationId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _apiClient.put('/worker/profile', data: {
        'city': newLocation,
        if (locationId != null) 'location_id': locationId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final data = response.data as Map<String, dynamic>;
      
      if (data['success']) {
        location = newLocation;
        // Kept in step with what was just sent, so the pin state on screen
        // does not wait for the next fetch to catch up.
        if (latitude != null) this.latitude = latitude;
        if (longitude != null) this.longitude = longitude;
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

  /*
      Save only what actually changed.

      This used to delete every skill and then add every skill back, one at a
      time. Two things came of that. The visible one: deleteSkill and addSkill
      each refetch the whole list and notify, so saving ten skills fired around
      forty requests and forty repaints, and you watched your skills disappear
      one by one and reappear one by one. The quiet one: it iterated _skills
      while deleteSkill was replacing that same list underneath it.

      A skill that is in both lists is now left completely alone - not deleted,
      not re-added, not touched. Only the difference is sent, and the list is
      fetched once at the end, so the UI changes exactly once.

      Matching is by skill id where both sides have one, and by name otherwise,
      because a custom skill typed in by hand has no id until the server gives
      it one.
  */
  Future<void> saveSkillsWithCategories(List<SkillModel> selectedSkills) async {
    bool same(WorkerSkillModel mine, SkillModel wanted) {
      if (mine.skillId != null && wanted.id > 0) return mine.skillId == wanted.id;
      return mine.skillName.toLowerCase() == wanted.name.toLowerCase();
    }

    try {
      // Copied, because the list underneath is replaced by the fetch below.
      final existing = List<WorkerSkillModel>.from(_skills);

      final removed = existing
          .where((mine) => !selectedSkills.any((wanted) => same(mine, wanted)))
          .toList();

      final added = selectedSkills
          .where((wanted) => !existing.any((mine) => same(mine, wanted)))
          .toList();

      if (removed.isEmpty && added.isEmpty) return;

      // Called directly rather than through deleteSkill/addSkill so the list
      // is not refetched and repainted between every single one.
      for (final skill in removed) {
        if (skill.id != null) {
          await _apiClient.delete('/worker/skills/${skill.id}');
        }
      }

      for (final wanted in added) {
        await _apiClient.post('/worker/skills', data: WorkerSkillModel(
          userId: 0, // Set by backend
          skillName: wanted.name,
          categoryId: wanted.categoryId,
          skillId: wanted.id > 0 ? wanted.id : null,
        ).toJson());
      }

      await fetchSkills();
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      // The screen would otherwise keep showing the pre-save list with no
      // sign that anything went wrong.
      notifyListeners();
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
  
  /*
      Categories and skills are fetched once per session, not per screen.

      They are a fixed taxonomy — 17 categories and 72 skills that do not change
      while someone uses the app — but `fetchCategories()` had no cache, and it
      is called from fifteen places, several of them unconditionally on every
      screen open. Posting a job, searching, adding skills and opening the home
      feed each re-downloaded the same list and each flipped `_isLoading`, which
      is what put a spinner in front of the category picker every single time.

      The server was never slow: these endpoints answer in about 260ms, and most
      of that is the tunnel. The wait was the app asking again and again.

      `force: true` is there for the case that genuinely needs it — creating a
      custom category, where the list really has changed.
  */
  bool _categoriesLoaded = false;
  bool _categoriesInFlight = false;
  // Note: fetchSkills() reads the worker's OWN skills, which change when they
  // add one, so it is deliberately not cached. Only the taxonomy is.

  /// True once the taxonomy is in memory, so callers can skip the round trip.
  bool get categoriesLoaded => _categoriesLoaded;

  Future<void> fetchCategories({bool force = false}) async {
    // An in-flight request must not be duplicated either: four screens built at
    // once would otherwise fire four identical calls before the first returns.
    if (!force && (_categoriesLoaded || _categoriesInFlight)) return;
    _categoriesInFlight = true;

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
        // Only on success. A failed fetch must stay retryable, or one bad
        // request early on would leave the picker permanently empty.
        _categoriesLoaded = true;
      } else {
        _errorMessage = data['message'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _categoriesInFlight = false;
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

  /*
      Every skill, in one request.

      The picker needs the whole catalogue once, to turn the names already on a
      profile back into real skill rows. It used to get there by calling
      fetchSkillsByCategory in a loop over every category: one HTTP round trip
      per category, run one after another, each one notifying listeners twice
      and rebuilding the entire screen. On a phone that is a visible stall
      before the screen becomes usable, and it is the frame drop people notice
      when they open their skills.

      The endpoint already returns everything when no category is given, so the
      loop was buying nothing.

      This deliberately does not touch _availableSkills. That list is what the
      category picker below shows, and filling it with every skill in the
      database would mean picking Carpentry and being offered hairdressing. The
      full catalogue is returned to the caller instead.
  */
  Future<List<SkillModel>> fetchAllSkills() async {
    try {
      final response = await _apiClient.get('/skills');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) return const [];

      return (data['data'] as List)
          .map((json) => SkillModel.fromJson(json))
          .toList();
    } catch (_) {
      // A name with no match still becomes a chip below, so failing here costs
      // the category grouping, not the user's skills.
      return const [];
    }
  }

  /*
      Upload a resume, replacing any existing one.

      The endpoints for this have existed since the feature was built and the
      app never called them, so a worker could not attach a CV at all - the
      one screen for it was an unreachable stub with an unimplemented file
      picker.

      pdf, doc and docx only, which is the server's rule too. A photo of a CV
      defeats the point for an employer trying to read it.
  */
  Future<bool> uploadResume(String filePath) async {
    try {
      final form = FormData.fromMap({
        'resume': await _upload(filePath),
      });

      final response = await _apiClient.postMultipart('/worker/profile/resume', form);
      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        _errorMessage = _extractErrorMessage(data['message']);
        return false;
      }

      _adoptResume(data['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      return false;
    }
  }

  Future<bool> deleteResume() async {
    try {
      final response = await _apiClient.delete('/worker/profile/resume');
      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        _errorMessage = _extractErrorMessage(data['message']);
        return false;
      }

      _adoptResume(data['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e.toString());
      return false;
    }
  }

  /// Takes the server's answer rather than assuming the change worked.
  void _adoptResume(dynamic payload) {
    if (payload is! Map) return;
    hasResume = payload['has_resume'] == true;
    resumeFileName = payload['file_name'] as String?;
    resumeUploadedAt = DateTime.tryParse(payload['uploaded_at'] as String? ?? '');
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
        formDataMap['document'] = await _upload(filePath);
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

  /// Carries a replacement document, for the reason given on updateLicense.
  Future<bool> updateCertification(int id, WorkerCertificationModel certification,
      {String? filePath}) async {
    try {
      final Response response;

      if (filePath != null) {
        final form = FormData.fromMap({
          ...certification.toJson(),
          '_method': 'PUT',
          'document': await _upload(filePath),
        });
        response = await _apiClient.postMultipart('/worker/certifications/$id', form);
      } else {
        response = await _apiClient.put('/worker/certifications/$id', data: certification.toJson());
      }

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

  /*
      The uploaded file keeps its own name.

      Both upload paths used to hand Dio a hardcoded filename - 'license.jpg',
      'certificate.jpg' - whatever the file actually was. Laravel derives the
      stored extension from that name, so a PDF was written to disk as a .jpg,
      and every screen that later tried to display it decoded a PDF as an image
      and drew a broken picture icon. The file was fine; the name was a lie.
  */
  static Future<MultipartFile> _upload(String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    return MultipartFile.fromFile(path, filename: name);
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
        formDataMap['document'] = await _upload(filePath);
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

  /*
      A replacement document now actually replaces.

      The edit screen has always let somebody pick a new file and has always
      returned it. This method ignored it and sent JSON, so the pick appeared
      to work, reported success, and left the original file in place with no
      way to ever correct it.

      Sent as multipart with _method=PUT because a real PUT cannot carry a file
      upload through Laravel's request parsing; the framework reads the
      override and routes it to the same controller method.
  */
  Future<bool> updateLicense(int id, WorkerLicenseModel license, {String? filePath}) async {
    try {
      final Response response;

      if (filePath != null) {
        final form = FormData.fromMap({
          ...license.toJson(),
          '_method': 'PUT',
          'document': await _upload(filePath),
        });
        response = await _apiClient.postMultipart('/worker/licenses/$id', form);
      } else {
        response = await _apiClient.put('/worker/licenses/$id', data: license.toJson());
      }

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
