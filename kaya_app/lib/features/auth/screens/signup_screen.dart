import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/ph_phone_field.dart';
import '../widgets/terms_modal.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _inputController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;
  bool _isPhoneMode              = false;
  bool _agreeToTerms             = false;

  String? _inputError;
  String? _passwordError;
  String? _confirmError;
  String? _googleError;
  String? _termsError;

  @override
  void dispose() {  
    _inputController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final input    = _inputController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmPasswordController.text;

    String? inputErr, passErr, confirmErr;

    if (input.isEmpty) {
      inputErr = _isPhoneMode ? 'Phone number is required' : 'Email is required';
    } else if (_isPhoneMode) {
      if (!isValidPHPhone(input)) {
        inputErr = 'Enter a valid PH number (e.g. 9171234567)';
      }
    } else {
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input)) {
        inputErr = 'Enter a valid email address';
      }
    }

    if (password.isEmpty) {
      passErr = 'Password is required';
    } else if (password.length < 8) {
      passErr = 'Password must be at least 8 characters';
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password';
    } else if (confirm != password) {
      confirmErr = 'Passwords do not match';
    }

    setState(() {
      _inputError    = inputErr;
      _passwordError = passErr;
      _confirmError  = confirmErr;
    });

    if (!_agreeToTerms) {
      setState(() => _termsError = 'You must agree to the Terms & Conditions to continue.');
      return false;
    }

    return inputErr == null && passErr == null && confirmErr == null;
  }

  Future<void> _handleSignup(AuthProvider auth) async {
    if (!_validate()) return;

    final credential = _isPhoneMode
        ? toPHE164(_inputController.text.trim())
        : _inputController.text.trim();

    final success = await auth.register(
      name: '', // Name will be set later during profile setup
      email: credential,
      password: _passwordController.text,
      passwordConfirmation: _confirmPasswordController.text,
      termsAccepted: true, // User has accepted terms via modal
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _inputError = auth.errorMessage ?? 'Sign up failed');
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
              Text('Create Account',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
              const SizedBox(height: 8),
              Text('Sign up to get started',
                  style: TextStyle(fontSize: 16, color: AppColors.neutral600)),
              const SizedBox(height: 40),

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
                  hint: 'Create a password',
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
              const SizedBox(height: 20),

              // ── Confirm Password ──────────────────────────────────────────
              _label('Confirm Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                onChanged: (_) => setState(() => _confirmError = null),
                decoration: _deco(
                  hint: 'Confirm your password',
                  icon: Icons.lock_outline,
                  errorText: _confirmError,
                  suffix: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.neutral500,
                    ),
                    onPressed: () =>
                        setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Terms ─────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreeToTerms,
                      onChanged: null, // Disabled - can only be checked via modal
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final accepted = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const TermsModal(),
                        );
                        if (accepted == true && mounted) {
                          setState(() {
                            _agreeToTerms = true;
                            _termsError = null;
                          });
                        }
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'I have read and agree to the ',
                          style: TextStyle(color: AppColors.neutral600, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' and ',
                              style: TextStyle(color: AppColors.neutral600),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_termsError != null) const SizedBox(height: 12),
              if (_termsError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _termsError!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // ── Google Error Message ──────────────────────────────────────
              if (_googleError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
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

              // ── Sign Up ───────────────────────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, auth, _) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : () => _handleSignup(auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(height: 22, width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign Up',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Row(children: [
                Expanded(child: Divider(color: AppColors.neutral300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Or sign up with',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 14)),
                ),
                Expanded(child: Divider(color: AppColors.neutral300)),
              ]),
              const SizedBox(height: 32),

              Row(children: [
                Expanded(child: _socialBtn(Icons.g_mobiledata, 'Google', () async {
                  // Clear previous error
                  setState(() => _googleError = null);
                  
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final googleData = await auth.initiateGoogleSignIn();
                  if (googleData == null) return; // User cancelled
                  
                  if (!mounted) return;
                  
                  // Try to complete signup - backend will check if email exists
                  final success = await auth.completeGoogleSignIn(
                    googleId: googleData['google_id'],
                    name: googleData['name'],
                    email: googleData['email'],
                    avatar: googleData['avatar'],
                    isSignup: true, // Tell backend this is signup attempt
                  );
                  
                  if (!mounted) return;
                  
                  if (success) {
                    // Should not happen during signup, but handle gracefully
                    Navigator.pushReplacementNamed(context, '/home');
                  } else {
                    // Check the error type
                    final error = auth.errorMessage ?? '';
                    
                    if (error.toLowerCase().contains('already registered') || 
                        error.toLowerCase().contains('already exists')) {
                      // Existing user trying to sign up - show inline error
                      setState(() => _googleError = 'This email is already registered. Please use the login screen instead.');
                    } else if (error.contains('Password is required')) {
                      // New user - needs to set password
                      Navigator.pushNamed(context, '/google-password', arguments: googleData);
                    } else {
                      // Other error - show it inline
                      setState(() => _googleError = error.isNotEmpty ? error : 'Google Sign-In failed. Please try again.');
                    }
                  }
                })),
                const SizedBox(width: 16),
                Expanded(child: _socialBtn(Icons.facebook, 'Facebook', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Facebook Sign-In coming soon')));
                })),
              ]),
              const SizedBox(height: 48),

              Center(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text('Sign In',
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

  Widget _socialBtn(IconData icon, String label, VoidCallback onPressed) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColors.neutral300),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.neutral700, size: 22),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.neutral700, fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      );
}
