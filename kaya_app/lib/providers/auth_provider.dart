import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/services/api_client.dart';
import '../data/services/message_cache.dart';
import '../data/services/realtime_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  /// The Web OAuth client ID, overridable at build time:
  ///   flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  ///
  /// Not a secret — it ships inside the APK either way. It is required because
  /// Android OAuth clients cannot mint ID tokens: the SDK only returns an
  /// `idToken` when it knows which server the token is meant for, and the
  /// backend then checks that same value as the token's audience.
  ///
  /// It has a defaultValue for the same reason ApiClient's host does: without
  /// one, any build that forgets the flag compiles in an empty string,
  /// `serverClientId` becomes null, the SDK returns no idToken, and Google
  /// sign-in fails with a message that points nowhere near the cause. Several
  /// debug APKs shipped exactly that way. The default must stay equal to
  /// GOOGLE_CLIENT_ID in the backend's .env — that is the audience the server
  /// validates the token against, so if they drift, every sign-in is rejected.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '217067120890-iro1gc0ab5agescr3oksi4gqg0j96chd.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;

  // NOTE: there is deliberately no `userType` getter. KAYA is hybrid — one
  // account can be both worker and employer — so the single `user_type` column
  // cannot describe it. Role is always derived from the profile-existence flags
  // below, which is also how the backend decides (User::isWorker/isEmployer).

  // Employer profile flags from /me endpoint
  bool get employerProfileExists => _user?['employer_profile_exists'] as bool? ?? false;
  String? get employerType => _user?['employer_type'] as String?;
  bool get employerSetupCompleted => _user?['employer_setup_completed'] as bool? ?? false;

  // Worker profile flags from /me endpoint
  bool get workerProfileExists => _user?['worker_profile_exists'] as bool? ?? false;
  bool get workerSetupCompleted => _user?['worker_setup_completed'] as bool? ?? false;

  /// True once the user has joined at least one side of the marketplace.
  /// When false the app is in "neutral" mode and shows the dual setup card.
  bool get hasAnyProfile => workerProfileExists || employerProfileExists;

  // ── Register ─────────────────────────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required bool termsAccepted,
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
        'terms_accepted': termsAccepted,
        if (phone != null) 'phone': phone,
        if (city != null) 'city': city,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;
      await _hydrateProfileFlags();

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
      await _hydrateProfileFlags();

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

      // The ID token is the only part the server trusts. Everything else here
      // is for showing the user which account they picked before they continue.
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        _errorMessage = 'Google Sign-In is not configured for this build. '
            'Rebuild with --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>.';
        notifyListeners();
        return null;
      }

      return {
        'id_token': idToken,
        // Shown on the confirmation screen only; never sent as identity.
        'email': googleUser.email,
      };
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Identity is carried entirely by [idToken]; the server reads nothing else.
  Future<bool> completeGoogleSignIn({
    required String idToken,
    String? password,
    bool isSignup = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/google-login', data: {
        'id_token': idToken,
        'is_signup': isSignup,
        if (password != null) 'password': password,
      });

      final data = response.data['data'];
      await ApiClient.saveToken(data['token'] as String);
      _user = data['user'] as Map<String, dynamic>;
      await _hydrateProfileFlags();

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

  /// Signs out locally first, then cleans up in the background.
  ///
  /// This used to await three network-dependent calls in a row: the server
  /// logout (30 second timeout), Google sign-out, and closing the WebSocket.
  /// Any one of them can hang — an unreachable API, a slow Play Services, a
  /// half-open socket whose `close()` never completes. The user tapped Logout
  /// and the app appeared frozen, sometimes permanently.
  ///
  /// Nothing here actually needs the network to succeed. Signing out means
  /// destroying the token on *this device*; revoking it server-side is a
  /// courtesy that can finish on its own, and if it never does the token is
  /// already unusable because it has been deleted locally.
  Future<void> logout() async {
    // Cached messages are readable without the network, so they must not
    // outlive the session — on a shared handset the next person to sign in
    // would otherwise open the app to someone else's conversations.
    unawaited(MessageCache.instance.clear());

    // Local, instant, and the only part that must not fail.
    await ApiClient.deleteToken();

    // disconnect() clears its listeners and subscriptions synchronously before
    // it awaits the socket close, so the next account cannot inherit this one's
    // channels even though this is not awaited.
    unawaited(RealtimeService.instance.disconnect());

    unawaited(_revokeTokenServerSide());
    unawaited(_googleSignIn.signOut().catchError((_) => null));

    _user = null;
    notifyListeners();
  }

  /// Tells the server to drop this device's token.
  ///
  /// Time-boxed and deliberately silent. The token is already gone locally, so
  /// a failure here leaves nothing usable behind — it only means the row
  /// lingers in personal_access_tokens until it is cleaned up.
  Future<void> _revokeTokenServerSide() async {
    try {
      await _api.post('/logout').timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline, unreachable, or already invalid. Nothing to tell the user.
    }
  }

  /// register/login/google-login all return the bare `User` model — it has no
  /// `worker_profile_exists`/`employer_profile_exists`/setup-completed keys,
  /// which only /me computes. Without this, `hasAnyProfile` reads those as
  /// missing (null → false) right after every single auth path, so the
  /// "Welcome to KAYA" dual-setup prompt showed even for accounts that
  /// already had a complete profile — until something else happened to call
  /// fetchMe() later (e.g. opening a profile setup screen).
  Future<void> _hydrateProfileFlags() async {
    try {
      final response = await _api.get('/me');
      _user = response.data['data'] as Map<String, dynamic>;
    } catch (_) {
      // Keep the raw auth-response user — a transient failure here shouldn't
      // undo a login/register that just succeeded.
    }

    // Every auth path funnels through here, so this is the one place the
    // socket needs opening. Not awaited: realtime is an enhancement, and
    // blocking the login screen on a WebSocket handshake would make a slow or
    // unreachable Reverb feel like a broken login.
    unawaited(RealtimeService.instance.connect());
  }

  // ── Fetch current user ───────────────────────────────────────────────────────

  /// True when the last [fetchMe] failed because the server could not be
  /// reached, rather than because the session was rejected.
  ///
  /// The startup screen uses this to offer a retry instead of dropping the
  /// user at login as though they had been signed out.
  bool _lastFetchWasNetworkError = false;
  bool get lastFetchWasNetworkError => _lastFetchWasNetworkError;

  Future<void> fetchMe() async {
    final token = await ApiClient.getToken();
    if (token == null) return;

    try {
      final response = await _api.get('/me');
      _user = response.data['data'] as Map<String, dynamic>;
      _lastFetchWasNetworkError = false;

      // Cold start with a stored token never touches the login path, so the
      // socket has to be opened here too.
      unawaited(RealtimeService.instance.connect());

      notifyListeners();
    } catch (_) {
      /*
          A dropped connection is not a rejected session.

          This used to delete the token on any exception, so a weak signal at
          launch — a slow tunnel, WiFi handing over, being on a jeepney —
          silently signed the user out of a session that was perfectly valid.
          They saw a long blank spinner and then the login screen, with nothing
          explaining why.

          Nothing is cleared here now. A session that really has expired comes
          back 401, and the interceptor in ApiClient already signs the user out
          and returns them to login for that case. Everything else is worth
          retrying, so the token stays where it is and the caller is told this
          was a connection problem.
      */
      _lastFetchWasNetworkError = true;
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
