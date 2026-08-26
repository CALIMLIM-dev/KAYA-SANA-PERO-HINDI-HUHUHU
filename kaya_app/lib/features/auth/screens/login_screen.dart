import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/ph_phone_field.dart';
import '../../../shared/widgets/suspension_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible   = false;
  bool _isPhoneMode         = false;

  String? _inputError;
  String? _passwordError;
  String? _googleError;

  /// Google sign-in spans an account picker and then a network call. Without
  /// this the button looked idle for the whole second half.
  bool _googleBusy = false;

  /// Tracked separately from AuthProvider.isLoading.
  ///
  /// Both sign-in paths go through the same provider, so a shared flag made the
  /// email button spin while Google was working — two buttons claiming to be
  /// doing the thing you asked for when only one of them is. Each button now
  /// reports on its own action.
  bool _emailBusy = false;

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final input    = _inputController.text.trim();
    final password = _passwordController.text;
    String? inputErr, passErr;

    if (input.isEmpty) {
      inputErr = _isPhoneMode ? 'Phone number is required' : 'Email is required';
    } else if (_isPhoneMode) {
      // Phone mode — must be valid PH number
      if (!isValidPHPhone(input)) {
        inputErr = 'Enter a valid PH number (e.g. 9171234567)';
      }
    } else {
      // Email mode — must contain @ and domain
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input)) {
        inputErr = 'Enter a valid email address';
      }
    }

    if (password.isEmpty) {
      passErr = 'Password is required';
    }

    setState(() { _inputError = inputErr; _passwordError = passErr; });
    return inputErr == null && passErr == null;
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    if (!_validate()) return;

    final credential = _isPhoneMode
        ? toPHE164(_inputController.text.trim())
        : _inputController.text.trim();

    setState(() => _emailBusy = true);

    final result = await auth.login(email: credential, password: _passwordController.text);

    if (!mounted) return;

    setState(() => _emailBusy = false);

    // Check if account is suspended - ALWAYS show generic message on login
    if (result['is_suspended'] == true) {
      SuspensionDialog.showOnLogin(
        context,
        'Your account has been suspended.', // Generic message, no specific reason
      );
      return;
    }
    
    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Show context-aware error — phone mode says "phone", email mode says "email"
      final serverMsg = auth.errorMessage ?? '';
      final displayMsg = serverMsg.contains('email') && _isPhoneMode
          ? 'Incorrect phone number or password'
          : serverMsg.isNotEmpty
              ? serverMsg
              : _isPhoneMode
                  ? 'Incorrect phone number or password'
                  : 'Incorrect email or password';
      setState(() => _passwordError = displayMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text('Welcome Back',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
              const SizedBox(height: 8),
              Text('Sign in to continue',
                  style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
              const SizedBox(height: 48),

              // ── Email or Phone ────────────────────────────────────────────
              _label(_isPhoneMode ? 'Phone Number' : 'Email'),
              const SizedBox(height: 8),
              if (_isPhoneMode)
                PhPhoneField(
                  controller: _inputController,
                  errorText: _inputError,
                  onChanged: (_) => setState(() => _inputError = null),
                  suffix: TextButton(
                    onPressed: () => setState(() {
                      _isPhoneMode = false;
                      _inputController.clear();
                      _inputError = null;
                    }),
                    child: Text('Use Email',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                )
              else
                TextField(
                  controller: _inputController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => _inputError = null),
                  decoration: _deco(
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                    errorText: _inputError,
                    suffix: TextButton(
                      onPressed: () => setState(() {
                        _isPhoneMode = true;
                        _inputController.clear();
                        _inputError = null;
                      }),
                      child: Text('Use Phone',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Password ──────────────────────────────────────────────────
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                onChanged: (_) => setState(() => _passwordError = null),
                decoration: _deco(
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  errorText: _passwordError,
                  suffix: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.neutral500,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                  child: Text('Forgot Password?',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Sign In ───────────────────────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, auth, _) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    // Disabled while EITHER path is running — two sign-ins at
                    // once is never wanted — but only spins for its own.
                    onPressed: _emailBusy || _googleBusy
                        ? null
                        : () => _handleLogin(auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: _emailBusy
                        ? const SizedBox(height: 22, width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Google Error Message ──────────────────────────────────────
              if (_googleError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _googleError!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _googleError = null),
                        child: Icon(Icons.close, color: AppColors.error, size: 18),
                      ),
                    ],
                  ),
                ),
              if (_googleError != null) const SizedBox(height: 24),

              Row(children: [
                Expanded(child: Divider(color: AppColors.neutral300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Or continue with',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 14)),
                ),
                Expanded(child: Divider(color: AppColors.neutral300)),
              ]),
              const SizedBox(height: 32),

              Row(children: [
                Expanded(child: _socialBtn(Icons.g_mobiledata, 'Google', () async {
                  // Never two sign-ins at once.
                  if (_emailBusy) return;

                  // Clear previous error
                  setState(() {
                    _googleError = null;
                    _googleBusy = true;
                  });

                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  try {
                    // Force account picker to show
                    final googleData = await auth.initiateGoogleSignIn();

                    // Cancelling the picker is not a failure — but the button
                    // has to come back to life either way, which is why every
                    // exit from here runs through the finally below.
                    if (googleData == null) return;
                    if (!mounted) return;

                    // Login attempt - backend will handle existing users automatically
                    final success = await auth.completeGoogleSignIn(
                      idToken: googleData['id_token'],
                      isSignup: false, // Tell backend this is login
                    );

                    if (!mounted) return;

                    if (success) {
                      Navigator.pushReplacementNamed(context, '/home');
                    } else {
                      setState(() => _googleError = auth.errorMessage ?? 'Google Sign-In failed. Please try again.');
                    }
                  } finally {
                    if (mounted) setState(() => _googleBusy = false);
                  }
                }, busy: _googleBusy)),
              ]),
              const SizedBox(height: 48),

              /*
                  Wrap, not Row.

                  A Row cannot break a line, so "Don't have an account? Sign
                  Up" was laid out on one line no matter how wide that line
                  needed to be. On a narrow phone at a large font it needed
                  more than the screen had, and the whole thing ran off the
                  right edge behind a striped bar - including the link, which
                  is the only way to reach the other screen.

                  Wrap puts the second half on its own line instead.
              */
              Center(child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: TextStyle(color: AppColors.neutral600, fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                    child: Text('Sign Up',
                        style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900));

  InputDecoration _deco({required String hint, required IconData icon, String? errorText, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.neutral400),
        prefixIcon: Icon(icon, color: AppColors.neutral500),
        suffixIcon: suffix,
        errorText: errorText,
        filled: true,
        fillColor: AppColors.neutral50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  /// A social sign-in button that can show it is working.
  ///
  /// This had no busy state at all. Tapping Google opened the account picker,
  /// then made a network call, and throughout the button looked idle and
  /// stayed tappable — so a slow connection read as a dead button, and a
  /// second tap started the whole flow again.
  Widget _socialBtn(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool busy = false,
  }) =>
      OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColors.neutral300),
        ),
        child: busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: AppColors.neutral700, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: AppColors.neutral700,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ]),
      );
}
