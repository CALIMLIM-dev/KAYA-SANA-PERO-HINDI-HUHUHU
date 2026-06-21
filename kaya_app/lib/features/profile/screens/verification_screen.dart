import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Verification Screen — handles all verification types
/// Arguments: { type: 'government_id' | 'phone' | 'email' | 'business_reg', title, subtitle }
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Phone verification
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _phoneVerified = false;

  // Email verification
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _emailVerified = false;

  // Document upload
  bool _documentUploaded = false;
  String? _uploadedFileName;
  bool _confirmChecked = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final type     = args?['type']     as String? ?? 'government_id';
    final title    = args?['title']    as String? ?? 'Verify';
    final subtitle = args?['subtitle'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(context, type, subtitle),
    );
  }

  Widget _buildBody(BuildContext context, String type, String subtitle) {
    switch (type) {
      case 'phone':
        return _buildPhoneVerification(context, subtitle);
      case 'email':
        return _buildEmailVerification(context, subtitle);
      default:
        return _buildDocumentUpload(context, type, subtitle);
    }
  }

  // ─── Phone Verification ───────────────────────────────────────────────────

  Widget _buildPhoneVerification(BuildContext context, String subtitle) {
    if (_phoneVerified) return _buildSuccessState('Phone number verified!');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(Icons.phone_android, 'Verify Phone Number', subtitle),
          const SizedBox(height: 32),

          if (!_otpSent) ...[
            const Text('Enter your phone number',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900)),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDeco(
                  hint: '+63 912 345 6789', icon: Icons.phone),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _phoneController.text.isNotEmpty && !_isLoading
                    ? () => _sendOTP()
                    : null,
                style: _primaryBtn(),
                child: _isLoading
                    ? _loader()
                    : const Text('Send OTP',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'OTP sent to ${_phoneController.text}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.success),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Change',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Enter the 6-digit OTP',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900)),
            const SizedBox(height: 10),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700),
              decoration: _inputDeco(hint: '------', icon: Icons.lock_outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Didn't receive it? ",
                    style: TextStyle(
                        fontSize: 13, color: AppColors.neutral500)),
                GestureDetector(
                  onTap: () => _sendOTP(),
                  child: const Text('Resend OTP',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _otpController.text.length == 6 && !_isLoading
                    ? () => _verifyOTP(context)
                    : null,
                style: _primaryBtn(),
                child: _isLoading
                    ? _loader()
                    : const Text('Verify',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Email Verification ───────────────────────────────────────────────────

  Widget _buildEmailVerification(BuildContext context, String subtitle) {
    if (_emailVerified) return _buildSuccessState('Email address verified!');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(Icons.email_outlined, 'Verify Email Address', subtitle),
          const SizedBox(height: 32),

          if (!_emailSent) ...[
            const Text('Enter your email address',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900)),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco(
                  hint: 'your.email@example.com', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _emailController.text.isNotEmpty && !_isLoading
                    ? () => _sendEmailVerification()
                    : null,
                style: _primaryBtn(),
                child: _isLoading
                    ? _loader()
                    : const Text('Send Verification Link',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('Check your email',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to ${_emailController.text}',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.neutral600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _emailVerified = true),
                      style: _primaryBtn(),
                      child: const Text("I've verified my email",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        setState(() {
                          _emailSent = false;
                          _emailController.clear();
                        }),
                    child: const Text('Use a different email',
                        style: TextStyle(color: AppColors.neutral500)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Document Upload ──────────────────────────────────────────────────────

  Widget _buildDocumentUpload(
      BuildContext context, String type, String subtitle) {
    if (_documentUploaded && _confirmChecked) {
      return _buildSuccessState('Document submitted for review!');
    }

    final icon = type == 'business_reg'
        ? Icons.business_center_outlined
        : Icons.badge_outlined;
    final docTypes = type == 'business_reg'
        ? 'DTI Certificate, SEC Registration, or Mayor\'s Permit'
        : 'Passport, SSS ID, PhilHealth, Driver\'s License, Voter\'s ID, or Postal ID';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(icon, subtitle, ''),
          const SizedBox(height: 24),

          // Accepted documents
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Accepted Documents',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(docTypes,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.neutral700, height: 1.5)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Upload area
          GestureDetector(
            onTap: () => _pickDocument(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _documentUploaded
                      ? AppColors.success
                      : AppColors.neutral300,
                  width: _documentUploaded ? 2 : 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: _documentUploaded
                  ? Column(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          _uploadedFileName ?? 'Document uploaded',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () =>
                              setState(() {
                                _documentUploaded = false;
                                _uploadedFileName = null;
                                _confirmChecked = false;
                              }),
                          child: const Text('Remove and re-upload',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.neutral500)),
                        ),
                      ],
                    )
                  : Column(
                      children: const [
                        Icon(Icons.upload_file_outlined,
                            size: 40, color: AppColors.neutral400),
                        SizedBox(height: 12),
                        Text('Tap to upload document',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral700)),
                        SizedBox(height: 4),
                        Text('JPG, PNG, or PDF — max 5MB',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.neutral400)),
                      ],
                    ),
            ),
          ),

          // Confirmation checkbox
          if (_documentUploaded) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () =>
                  setState(() => _confirmChecked = !_confirmChecked),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: _confirmChecked
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _confirmChecked
                            ? AppColors.primary
                            : AppColors.neutral400,
                      ),
                    ),
                    child: _confirmChecked
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I confirm this document is genuine. Submitting fake documents will result in permanent account ban and may be reported to authorities.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.neutral700,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _documentUploaded && _confirmChecked && !_isLoading
                  ? () => _submitDocument(context)
                  : null,
              style: _primaryBtn(),
              child: _isLoading
                  ? _loader()
                  : const Text('Submit for Verification',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Our team reviews submissions within 1–2 business days. You will be notified once verified.',
            style: TextStyle(
                fontSize: 12, color: AppColors.neutral400, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Success state ────────────────────────────────────────────────────────

  Widget _buildSuccessState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified,
                  size: 56, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            Text(message,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Your profile will show a verification badge once confirmed.',
              style: TextStyle(fontSize: 14, color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: _primaryBtn(),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(IconData icon, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.neutral500, height: 1.5)),
        ],
      ],
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.neutral400, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.neutral500, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neutral300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.neutral300,
        disabledForegroundColor: AppColors.neutral500,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );

  Widget _loader() => const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
          color: Colors.white, strokeWidth: 2));

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
  }

  Future<void> _verifyOTP(BuildContext context) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isLoading = false;
      _phoneVerified = true;
    });
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
  }

  void _pickDocument() {
    // TODO: Replace with file_picker package
    setState(() {
      _documentUploaded = true;
      _uploadedFileName = 'document_id.pdf';
    });
  }

  Future<void> _submitDocument(BuildContext context) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      _isLoading = false;
      _documentUploaded = true;
      _confirmChecked = true;
    });
    // Show success by rebuilding
    setState(() {});
  }
}
