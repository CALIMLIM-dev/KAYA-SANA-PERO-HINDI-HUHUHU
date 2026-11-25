import 'dart:async';
import '../../../core/widgets/loading.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/otp_field.dart';

/// The code from the email, for Forgot Password and for signing up (with
/// `signup_password` in the arguments, the code makes the account).
class VerifyResetCodeScreen extends StatefulWidget {
  const VerifyResetCodeScreen({super.key});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  /// One controller for the whole code. Six of them — one per box — is the
  /// obvious build and the reason a code pasted from the email used to land
  /// only in the first box.
  final TextEditingController _codeCtrl = TextEditingController();
  String? _errorMessage;

  /// A code was just sent to reach this screen, so Resend waits a minute -
  /// the same minute the server holds.
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(60);
  }

  Map<String, dynamic> get _args => ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

  /// Set when signing up.
  String? get _signupPassword => _args['signup_password'] as String?;

  bool _readWait = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readWait) return;
    _readWait = true;
    // Coming back while a code is still out: what is left of its minute.
    final wait = _args['wait'] as int?;
    if (wait != null) _startCooldown(wait);
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _code => _codeCtrl.text;

  /// One check at a time: the box and the button can both ask.
  bool _verifying = false;

  Future<void> _handleVerify(String email, AuthProvider auth) async {
    if (_verifying) return;
    if (_code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code');
      return;
    }

    _verifying = true;
    final password = _signupPassword;
    final success = password != null
        ? await auth.register(email: email, password: password, code: _code)
        : await auth.verifyResetCode(email: email, code: _code);
    _verifying = false;

    if (!mounted) return;
    if (success && password != null) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } else if (success) {
      Navigator.pushReplacementNamed(
        context,
        '/reset-password',
        arguments: {'email': email, 'code': _code},
      );
    } else {
      setState(() => _errorMessage = auth.errorMessage);
    }
  }

  Future<void> _handleResendCode(String email, AuthProvider auth) async {
    final password = _signupPassword;
    final success = password != null
        ? await auth.sendSignupCode(email: email, password: password)
        : await auth.sendResetCode(email: email);

    if (!mounted) return;
    if (success) {
      AppToast.info(context, 'A new code is on its way.');
      _codeCtrl.clear();
      setState(() => _errorMessage = null);
      _startCooldown(60);
    } else {
      setState(() => _errorMessage = auth.errorMessage);
      final wait = auth.resetRetryAfter;
      if (wait != null) _startCooldown(wait);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _args['email'] as String;

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
                'Verify Code',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 16, color: AppColors.neutral600),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              OtpField(
                controller: _codeCtrl,
                autofocus: true,
                hasError: _errorMessage != null,
                onCompleted: (_) =>
                    _handleVerify(email, context.read<AuthProvider>()),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppColors.error, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Verify button
              Consumer<AuthProvider>(
                builder: (context, auth, _) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : () => _handleVerify(email, auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SmallSpinner.white()
                        : const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend code link. Wrap for the reason given on the login screen.
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Not there? Check Spam. ',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 15),
                    ),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) => GestureDetector(
                        onTap: auth.isLoading || _cooldown > 0
                            ? null
                            : () => _handleResendCode(email, auth),
                        child: Text(
                          _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend',
                          style: TextStyle(
                            color: auth.isLoading || _cooldown > 0
                                ? AppColors.neutral400
                                : AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
