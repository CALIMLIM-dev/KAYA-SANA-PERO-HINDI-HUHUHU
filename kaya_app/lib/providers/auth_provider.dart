import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/services/api_client.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;
  // user_type is set later when user sets up a profile on home screen
  String? get userType => _user?['user_type'] as String?;
  
  // Employer profile flags from /me endpoint
  bool get employerProfileExists => _user?['employer_profile_exists'] as bool? ?? false;
  String? get employerType => _user?['employer_type'] as String?;
  
  // Worker profile flags from /me endpoint
  bool get workerProfileExists => _user?['worker_profile_exists'] as bool? ?? false;
  bool get workerSetupCompleted => _user?['worker_setup_completed'] as bool? ?? false;

  // ── Register ─────────────────────────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? city,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null) 'phone': phone,
        if (city != null) 'city': city,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;

      _isLoading = false;
      notifyListeners();
      return {'success': true};
    } catch (e) {
      _isLoading = false;
      
      // Parse the error - ApiClient throws exceptions with response data
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      
      // Check if backend returned suspension data
      // Backend returns 403 with message "Account suspended"
      if (errorMsg.contains('Account suspended')) {
        notifyListeners();
        return {
          'success': false,
          'is_suspended': true,
          'suspended_reason': '', // NEVER show actual reason on login
        };
      }
      
      _errorMessage = errorMsg;
      notifyListeners();
      return {'success': false};
    }
  }

  // ── Check Suspension Status ──────────────────────────────────────────────────

  Future<Map<String, dynamic>?> checkSuspensionStatus() async {
    try {
      final response = await _api.get('/check-status');
      final data = response.data['data'];
      
      if (data['is_suspended'] == true) {
        return {
          'is_suspended': true,
          'suspended_reason': data['suspended_reason'] ?? 'Your account has been suspended.',
        };
      }
      
      return {'is_suspended': false};
    } catch (e) {
      // If error contains suspension info
      final errorMsg = e.toString();
      if (errorMsg.contains('suspended')) {
        return {
          'is_suspended': true,
          'suspended_reason': 'Your account has been suspended.',
        };
      }
      return null;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> initiateGoogleSignIn() async {
    try {
      // Sign out first to force account picker to show
      await _googleSignIn.signOut();
      
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Return Google user data WITHOUT the name
      return {
        'google_id': googleUser.id,
        'name': '', // Don't use Google name - user will set it later
        'email': googleUser.email,
        'avatar': googleUser.photoUrl,
      };
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> completeGoogleSignIn({
    required String googleId,
    required String name,
    required String email,
    String? avatar,
    String? password,
    bool isSignup = false, // New parameter
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/google-login', data: {
        'google_id': googleId,
        'name': name,
        'email': email,
        'avatar': avatar,
        'is_signup': isSignup, // Pass to backend
        if (password != null) 'password': password,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Legacy method for backward compatibility
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _api.post('/google-login', data: {
        'google_id': googleUser.id,
        'name': '', // Don't fetch name from Google
        'email': googleUser.email,
        'avatar': googleUser.photoUrl,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } catch (_) {}

    await _googleSignIn.signOut().catchError((_) => null);
    await ApiClient.deleteToken();
    _user = null;
    notifyListeners();
  }

  // ── Fetch current user ───────────────────────────────────────────────────────

  Future<void> fetchMe() async {
    final token = await ApiClient.getToken();
    if (token == null) return;

    try {
      final response = await _api.get('/me');
      _user = response.data['data'] as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {
      await ApiClient.deleteToken();
      _user = null;
      notifyListeners();
    }
  }

  // ── Update current user (name, phone) ────────────────────────────────────────

  Future<bool> updateMe({String? name, String? phone}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      
      final response = await _api.patch('/me', data: data);
      if (response.data['success']) {
        // Update local user data
        if (_user != null) {
          _user!['name'] = name ?? _user!['name'];
          _user!['phone'] = phone ?? _user!['phone'];
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Forgot Password ──────────────────────────────────────────────────────────

  Future<bool> sendResetCode({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/forgot-password', data: {'email': email});
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyResetCode({required String email, required String code}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/verify-reset-code', data: {'email': email, 'code': code});
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/reset-password', data: {
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
