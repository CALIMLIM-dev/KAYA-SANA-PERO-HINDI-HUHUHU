import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/terms_modal.dart';

class GooglePasswordScreen extends StatefulWidget {
  const GooglePasswordScreen({super.key});

  @override
  State<GooglePasswordScreen> createState() => _GooglePasswordScreenState();
}

class _GooglePasswordScreenState extends State<GooglePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String? _passwordError;
  String? _confirmPasswordError;

  /*
      Terms are gated here, in the app.

      Google's native Android sign-in does not reliably show its consent
      screen with the terms and privacy links - for basic email/profile scopes
      it just returns the account, so a signup would agree to nothing. This is
      the last step before a Google account exists, so KAYA's own terms are
      shown and required here, the same as the email signup form, with the
      links opening the same scroll-through documents.
  */
  bool _agreeToTerms = false;
  String? _termsError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    String? passErr, confirmErr;

    if (password.isEmpty) {
      passErr = 'Password is required';
    } else if (password.length < 8) {
      passErr = 'Password must be at least 8 characters';
    }

    if (confirmPassword.isEmpty) {
      confirmErr = 'Please confirm your password';
    } else if (password != confirmPassword) {
      confirmErr = 'Passwords do not match';
    }

    setState(() {
      _passwordError = passErr;
      _confirmPasswordError = confirmErr;
    });
    return passErr == null && confirmErr == null;
  }

  Future<void> _handleComplete(Map<String, dynamic> googleData, AuthProvider auth) async {
    final passwordOk = _validate();

    // Checked alongside the password so both errors show on the same tap.
    if (!_agreeToTerms) {
      setState(() => _termsError =
          'You must agree to the Terms & Conditions to continue.');
    }
    if (!passwordOk || !_agreeToTerms) return;

    final success = await auth.completeGoogleSignIn(
      idToken: googleData['id_token'],
      password: _passwordController.text,
      isSignup: true, // This is a new account signup
      termsAccepted: _agreeToTerms,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _passwordError = auth.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.neutral900),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.neutral100,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 40),

              // Header
              Text(
                'Set Your Password',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a password to secure your account.',
                style: TextStyle(fontSize: 16, color: AppColors.neutral600),
              ),
              const SizedBox(height: 48),

              // Password
              Text(
                'Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                onChanged: (_) => setState(() => _passwordError = null),
                decoration: InputDecoration(
                  hintText: 'Create password',
                  hintStyle: TextStyle(color: AppColors.neutral400),
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.neutral500),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.neutral500,
                    ),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  errorText: _passwordError,
                  filled: true,
                  fillColor: AppColors.neutral50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Password
              Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                onChanged: (_) => setState(() => _confirmPasswordError = null),
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  hintStyle: TextStyle(color: AppColors.neutral400),
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.neutral500),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.neutral500,
                    ),
                    onPressed: () => setState(() =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                  errorText: _confirmPasswordError,
                  filled: true,
                  fillColor: AppColors.neutral50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              // Terms gate — Google's native sign-in does not reliably show
              // its own, so KAYA asks here. Same as the email signup form.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreeToTerms,
                      onChanged: (v) => setState(() {
                        _agreeToTerms = v ?? false;
                        if (_agreeToTerms) _termsError = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                          style: TextStyle(
                              color: AppColors.neutral600, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
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
              if (_termsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _termsError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),

              // Complete button
              Consumer<AuthProvider>(
                builder: (context, auth, _) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        auth.isLoading ? null : () => _handleComplete(googleData, auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Complete Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
