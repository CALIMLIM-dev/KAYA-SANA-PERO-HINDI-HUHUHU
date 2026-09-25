import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/otp_field.dart';
import '../../../core/constants/employer_type.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/// Verification Screen
/// Arguments: { type: 'government_id' | 'phone' | 'email' | 'business_reg', title, subtitle }
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Phone
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _phoneVerified = false;

  // Email
  final _emailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  bool _emailSent = false;
  bool _emailVerified = false;

  /// The server's own words when a code is refused — wrong, expired, out of
  /// attempts, or no SMS provider configured. Shown rather than replaced with
  /// something invented here.
  String? _verifyError;

  final ApiClient _api = ApiClient();

  // Document
  String? _docPath;
  String? _docName;
  List<int>? _docBytes;
  
  // Selfie with ID
  String? _selfiePath;
  String? _selfieName;
  
  // ID Type dropdown
  String? _selectedIdType;
  final _customIdCtrl = TextEditingController();

  // A company's TIN, given with its business document.
  final _tinCtrl = TextEditingController();
  
  bool _confirmed = false;
  bool _submitted = false;

  bool _isLoading = false;

  /// Seconds left before another code may be asked for. Sending is throttled
  /// on the server too; this is so the button says so instead of failing.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;

    // The code goes to the address and number held on the account, so those
    // are what the fields have to start from. Starting blank is what made
    // "Send OTP" answer "add a phone number to your account first" to
    // somebody looking straight at a filled-in field.
    final user = context.read<AuthProvider>().user;
    _phoneCtrl.text = (user?['phone'] as String?) ?? '';
    _emailCtrl.text = (user?['email'] as String?) ?? '';
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _emailCodeCtrl.dispose();
    _customIdCtrl.dispose();
    _tinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final type     = args?['type']     as String? ?? 'government_id';
    final title    = args?['title']    as String? ?? 'Verify';
    final subtitle = args?['subtitle'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        return _buildPhone(subtitle);
      case 'email':
        return _buildEmail(subtitle);
      default:
        return _buildDocument(context, type, subtitle);
    }
  }

  // ── Phone ─────────────────────────────────────────────────────────────────

  Widget _buildPhone(String subtitle) {
    if (_phoneVerified) return _successState('Phone number verified');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.phone_android, 'Verify Phone Number', subtitle),
          const SizedBox(height: 32),
          if (!_otpSent) ...[
            _label('Phone number'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {
                if (_verifyError != null) _verifyError = null;
              }),
              decoration: _deco(hint: '09XX XXX XXXX', icon: Icons.phone),
            ),
            const SizedBox(height: 6),
            const Text(
              'We text a 6-digit code to this number. Saving it here updates '
              'your account.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
            // Where "phone verification is not available yet" lands when no
            // SMS provider is configured. Better than a spinner that used to
            // resolve into a success the server knew nothing about.
            if (_verifyError != null) ...[
              const SizedBox(height: 10),
              Text(_verifyError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Send code',
              enabled: _phoneCtrl.text.trim().isNotEmpty && !_isLoading,
              isLoading: _isLoading,
              onPressed: _sendOTP,
            ),
          ] else
            ..._codeStep(
              sentTo: _phoneCtrl.text.trim(),
              controller: _otpCtrl,
              onChangeTarget: () => setState(() {
                _otpSent = false;
                _otpCtrl.clear();
                _verifyError = null;
              }),
              onVerify: _verifyOTP,
              onResend: _sendOTP,
            ),
        ],
      ),
    );
  }

  // ── Email ─────────────────────────────────────────────────────────────────

  Widget _buildEmail(String subtitle) {
    if (_emailVerified) return _successState('Email address verified');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.email_outlined, 'Verify Email Address', subtitle),
          const SizedBox(height: 32),
          if (!_emailSent) ...[
            _label('Email address'),
            const SizedBox(height: 8),
            /*
                Shown, not edited.

                The address is the sign-in identity: `PATCH /me` does not
                accept one and the code always goes to `users.email`. This was
                an editable field with a "Use a different email" button under
                it, neither of which could change anything — you could type a
                new address, watch the code go to the old one, and never be
                told why.
            */
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(children: [
                const Icon(Icons.email_outlined,
                    size: 20, color: AppColors.neutral500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emailCtrl.text.trim().isEmpty
                        ? 'No email on this account'
                        : _emailCtrl.text.trim(),
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.neutral900),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is your sign-in address, so it cannot be changed here.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
            if (_verifyError != null) ...[
              const SizedBox(height: 10),
              Text(_verifyError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Send code',
              enabled: _emailCtrl.text.trim().isNotEmpty && !_isLoading,
              isLoading: _isLoading,
              onPressed: _sendEmail,
            ),
          ] else ...[
            /*
                A code the server checks, not a button that trusts you.

                This was "I've verified my email" wired to
                `setState(() => _emailVerified = true)` — a self-service
                verification button. It told the server nothing, so the badge
                reverted the moment the parent screen refetched.
            */
            ..._codeStep(
              sentTo: _emailCtrl.text.trim(),
              controller: _emailCodeCtrl,
              onVerify: _verifyEmailCode,
              onResend: _sendEmail,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocument(BuildContext context, String type, String subtitle) {
    if (_submitted) return _successState('Document sent for review');

    final isGovID = type == 'government_id';
    final isBusiness = type == 'business_reg';
    
    final idTypes = [
      'Passport',
      'SSS ID',
      'PhilHealth ID',
      'Driver\'s License',
      'Voter\'s ID',
      'Postal ID',
      'PRC ID',
      'UMID',
      'Other',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header WITHOUT icon
          Text(subtitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
          const SizedBox(height: 24),

          if (isGovID) ...[
            // ID Type Dropdown
            const Text('ID Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedIdType,
                  hint: const Text('Select ID Type'),
                  isExpanded: true,
                  items: idTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) => setState(() => _selectedIdType = val),
                ),
              ),
            ),
            
            if (_selectedIdType == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customIdCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Specify ID Type',
                  hintText: 'e.g. Barangay ID',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Camera capture required for both ID and selfie',
                      style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ID Photo Capture
            const Text('1. Capture Your ID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
            const SizedBox(height: 8),
            _buildCaptureBox(
              label: 'ID Photo',
              path: _docPath,
              name: _docName,
              onCapture: () async {
                final result = await context.read<VerificationProvider>().capturePhoto();
                if (result != null) {
                  setState(() {
                    _docPath = result['path'] as String?;
                    _docName = result['name'] as String;
                  });
                }
              },
              onClear: () => setState(() { _docPath = null; _docName = null; }),
            ),
            
            const SizedBox(height: 20),
            
            // Selfie with ID Capture
            const Text('2. Capture Selfie with ID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text('Hold your ID next to your face', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
            const SizedBox(height: 8),
            _buildCaptureBox(
              label: 'Selfie with ID',
              path: _selfiePath,
              name: _selfieName,
              onCapture: () async {
                final result = await context.read<VerificationProvider>().capturePhoto();
                if (result != null) {
                  setState(() {
                    _selfiePath = result['path'] as String?;
                    _selfieName = result['name'] as String;
                  });
                }
              },
              onClear: () => setState(() { _selfiePath = null; _selfieName = null; }),
            ),
          ] else ...[
            // Business Registration or other docs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Accepted Documents',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    isBusiness 
                      ? 'DTI Certificate, SEC Registration, or Mayor\'s Permit'
                      : 'Valid document',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5)
                  ),
                ],
              ),
            ),

            /*
                The TIN, for a company.

                Both a DTI certificate and a BIR 2303 print it, so the admin
                checks the number against the document rather than asking for
                another upload. Only a company account sees the field: an
                individual has no business TIN, and the server refuses one.
            */
            if (isBusiness && _isCompanyAccount(context)) ...[
              const SizedBox(height: 20),
              _label('Business TIN'),
              const SizedBox(height: 8),
              TextField(
                controller: _tinCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _deco(hint: '123-456-789-000', icon: Icons.badge_outlined),
              ),
              const SizedBox(height: 6),
              const Text(
                'As printed on your DTI certificate or BIR 2303.',
                style: TextStyle(fontSize: 12, color: AppColors.neutral500),
              ),
            ],
            const SizedBox(height: 24),
            
            GestureDetector(
              onTap: _pickDocument,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _docName != null ? AppColors.success : AppColors.neutral300,
                    width: _docName != null ? 2 : 1.5,
                  ),
                ),
                child: _docName != null
                    ? Column(
                        children: [
                          if (_isImage()) ...[
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                              child: _buildImagePreview(),
                            ),
                          ] else ...[
                            Container(
                              height: 140,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.error),
                                  const SizedBox(height: 8),
                                  Text(_docName ?? '',
                                      style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_docName ?? 'Document selected',
                                      style: const TextStyle(fontSize: 13.5, color: AppColors.success),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _docPath = null; _docName = null;
                                    _docBytes = null; _confirmed = false;
                                  }),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(children: [
                          Icon(Icons.upload_file_outlined, size: 40, color: AppColors.neutral400),
                          SizedBox(height: 12),
                          Text('Tap to upload document',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
                          SizedBox(height: 4),
                          Text('JPG, PNG, or PDF — max 5MB',
                              style: TextStyle(fontSize: 12, color: AppColors.neutral400)),
                        ]),
                      ),
              ),
            ),
          ],

          if ((isGovID && _docPath != null && _selfiePath != null) || (!isGovID && _docName != null)) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => setState(() => _confirmed = !_confirmed),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: _confirmed ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _confirmed ? AppColors.primary : AppColors.neutral400),
                    ),
                    child: _confirmed
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'I confirm these documents are genuine. Submitting fake documents will result in permanent account ban.',
                      style: TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          Consumer<VerificationProvider>(
            builder: (context, vp, _) {
              bool canSubmit = _confirmed && !vp.isLoading;
              if (isGovID) {
                canSubmit = canSubmit && _selectedIdType != null && _docPath != null && _selfiePath != null;
                if (_selectedIdType == 'Other') {
                  canSubmit = canSubmit && _customIdCtrl.text.trim().isNotEmpty;
                }
              } else {
                canSubmit = canSubmit && (_docPath != null || _docBytes != null);
              }
              
              return _primaryButton(
                label: 'Submit for Verification',
                enabled: canSubmit,
                isLoading: vp.isLoading,
                onPressed: () => _submitDocument(context, type),
              );
            },
          ),

          const SizedBox(height: 16),
          const Text(
            'Our team reviews submissions within 1–2 business days.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral400, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureBox({
    required String label,
    required String? path,
    required String? name,
    required VoidCallback onCapture,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: name != null ? AppColors.success : AppColors.neutral300,
            width: name != null ? 2 : 1.5,
          ),
        ),
        child: name != null
            ? Column(
                children: [
                  if (path != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.file(
                        File(path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('$label captured',
                              style: const TextStyle(fontSize: 13.5, color: AppColors.success),
                              overflow: TextOverflow.ellipsis),
                        ),
                        TextButton(
                          onPressed: onClear,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Retake', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  const Icon(Icons.camera_alt, size: 36, color: AppColors.neutral400),
                  const SizedBox(height: 8),
                  Text('Tap to capture $label',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
                ]),
              ),
      ),
    );
  }

  // ── Success ───────────────────────────────────────────────────────────────

  Widget _successState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.verified, size: 56, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            const Text(
              'Under Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.neutral900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Our team is reviewing your documents. This usually takes 1-2 business days.',
              style: TextStyle(fontSize: 14, color: AppColors.neutral600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Once approved, you\'ll receive a verified badge that builds trust with other users.',
              style: TextStyle(fontSize: 14, color: AppColors.primary, height: 1.5, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _primaryButton(
              label: 'Done',
              enabled: true,
              onPressed: () => Navigator.pop(context, {
                'success': true,
                'documentPath': _docPath,
                'documentName': _docName,
                'documentBytes': _docBytes,
                'selfiePath': _selfiePath,
                'selfieName': _selfieName,
                'idType': _selectedIdType == 'Other' ? _customIdCtrl.text.trim() : _selectedIdType,
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  bool _isImage() {
    if (_docName == null) return false;
    final ext = _docName!.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(ext);
  }

  Widget _buildImagePreview() {
    if (_docBytes != null) {
      return Image.memory(
        Uint8List.fromList(_docBytes!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
      );
    }
    if (_docPath != null) {
      return Image.file(
        File(_docPath!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _pickDocument() async {
    final result = await context.read<VerificationProvider>().pickDocument();
    if (result != null) {
      setState(() {
        _docPath  = result['path'] as String?;
        _docName  = result['name'] as String;
        // Store bytes for web
        if (result['bytes'] != null) {
          _docBytes = List<int>.from(result['bytes'] as List);
        }
      });
    }
  }

  Future<void> _submitDocument(BuildContext context, String type) async {
    if (_docName == null) return;
    final vp = context.read<VerificationProvider>();

    /*
        One submission per document, until it is answered.

        The cards no longer open this screen while something is under review,
        but a notification tap still can, and so can a back gesture onto a
        screen left open from before. Without this the queue collected two and
        three copies of the same ID from people who were only checking on it -
        and an admin then had to work out which one to act on.

        Rejected is deliberately not blocked: being told no and sending a
        better photo is the whole point of that state.
    */
    final existing = vp.statusFor(type);
    if (existing == 'pending' || existing == 'verified') {
      AppToast.info(
        context,
        existing == 'verified'
            ? 'This is already verified.'
            : 'This is already under review. We will let you know.',
      );
      return;
    }

    bool success;
    if (type == 'government_id') {
      // Government ID needs both ID photo and selfie
      if (_docPath == null || _selfiePath == null) {
        AppToast.error(context, 'Please capture both ID and selfie photos');
        return;
      }
      
      final idType = _selectedIdType == 'Other' 
          ? _customIdCtrl.text.trim() 
          : _selectedIdType ?? '';
      
      success = await vp.submitGovernmentID(
        idType: idType,
        idPhotoPath: _docPath!,
        selfiePhotoPath: _selfiePath!,
      );
    } else {
      // Other document types
      if (type == 'business_reg' && _isCompanyAccount(context) && _tinCtrl.text.trim().isEmpty) {
        AppToast.error(context, 'Please enter your business TIN.');
        return;
      }

      success = await vp.submitDocument(
        type: type,
        fileName: _docName!,
        filePath: _docPath,
        fileBytes: _docBytes,
        tin: _isCompanyAccount(context) ? _tinCtrl.text : null,
      );
    }
    
    if (!mounted) return;
    if (success) {
      setState(() => _submitted = true);
    } else if (context.mounted) {
      AppToast.error(context, vp.errorMessage ?? 'Submission failed');
    }
  }

  /*
      Real verification.

      All three of these were `Future.delayed` followed by a success flag.
      _verifyOTP never read _otpCtrl at all, so any six digits passed, and the
      email step had a button that simply declared itself verified. Nothing
      reached the server, so the badge they implied did not exist — and the
      parent screen's refetch silently reverted it, which is why it looked
      like the verification "didn't save".

      The server now issues a hashed code with a ten-minute window, counts
      wrong attempts, and burns the code after five. The messages below come
      from it rather than being invented here.
  */

  /*
      Save the number, then ask for the code.

      The server sends to `users.phone` — it takes no number in the request —
      so sending before saving a changed one texts the old number, and sending
      with nothing saved is refused outright. The field on this screen used to
      be read by nothing at all: you typed a number, pressed Send OTP, and the
      server answered "add a phone number to your account first".
  */
  Future<void> _sendOTP() async {
    final phone = _phoneCtrl.text.trim();

    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      setState(() => _verifyError = 'That does not look like a mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _verifyError = null;
    });

    final auth = context.read<AuthProvider>();

    if (phone != ((auth.user?['phone'] as String?) ?? '').trim()) {
      final saved = await auth.updateMe(phone: phone);
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _isLoading = false;
          _verifyError = auth.errorMessage ?? 'Could not save that number.';
        });
        return;
      }
    }

    try {
      final res = await _api.post('/contact-verification/phone/send');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpSent = true;
        _otpCtrl.clear();
      });
      _startCooldown();
      AppToast.success(context, res.data['message'] as String? ?? 'Code sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // A missing SMS provider answers 503 with an explanation. Showing it
        // beats a spinner that resolves into a lie.
        _verifyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyOTP() async {
    final code = _otpCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _verifyError = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _verifyError = null;
    });

    try {
      await _api.post('/contact-verification/phone/verify', data: {'code': code});
      if (!mounted) return;
      // Pull the account down again so the row that sent us here shows
      // Verified when this screen pops, rather than the old state.
      await context.read<AuthProvider>().fetchMe();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phoneVerified = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _verifyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendEmail() async {
    setState(() {
      _isLoading = true;
      _verifyError = null;
    });

    try {
      final res = await _api.post('/contact-verification/email/send');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
        _emailCodeCtrl.clear();
      });
      _startCooldown();
      AppToast.success(context, res.data['message'] as String? ?? 'Code sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _verifyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Replaces the "I've verified my email" button, which set a flag and told
  /// the server nothing.
  Future<void> _verifyEmailCode() async {
    final code = _emailCodeCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _verifyError = 'Enter the 6-digit code from the email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _verifyError = null;
    });

    try {
      await _api.post('/contact-verification/email/verify', data: {'code': code});
      if (!mounted) return;
      await context.read<AuthProvider>().fetchMe();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailVerified = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _verifyError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _header(IconData icon, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.neutral500, height: 1.5)),
        ],
      ],
    );
  }

  bool _isCompanyAccount(BuildContext context) =>
      context.read<EmployerProfileProvider>().profile?.employerType ==
      EmployerType.company;

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900));

  /*
      The second half of both flows, written once.

      Phone and email ask for the same thing — six digits, ten minutes, five
      guesses — so they ask for it the same way. They used to differ in every
      respect: one a letter-spaced line, the other a centred grey box, one
      offering "Resend OTP" and the other "Send a new code".

      [onChangeTarget] is only passed where the value can actually be changed,
      which is the phone. Email is the sign-in address and has no such button,
      rather than one that clears a field to no effect.
  */
  List<Widget> _codeStep({
    required String sentTo,
    required TextEditingController controller,
    required Future<void> Function() onVerify,
    required Future<void> Function() onResend,
    VoidCallback? onChangeTarget,
  }) {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Code sent to $sentTo',
                style: const TextStyle(fontSize: 13.5, color: AppColors.success)),
          ),
          if (onChangeTarget != null)
            TextButton(
              onPressed: _isLoading ? null : onChangeTarget,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Change',
                  style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
        ]),
      ),
      const SizedBox(height: 28),
      _label('Enter the 6-digit code'),
      const SizedBox(height: 12),
      OtpField(
        controller: controller,
        autofocus: true,
        enabled: !_isLoading,
        hasError: _verifyError != null,
        // Six digits in means there is nothing left to decide, so submit
        // rather than making them reach for the button as well.
        onCompleted: (_) {
          if (!_isLoading) onVerify();
        },
      ),
      if (_verifyError != null) ...[
        const SizedBox(height: 10),
        Text(_verifyError!,
            style: const TextStyle(fontSize: 12, color: AppColors.error)),
      ],
      const SizedBox(height: 14),
      Row(children: [
        const Text("Didn't get it? ",
            style: TextStyle(fontSize: 13.5, color: AppColors.neutral500)),
        if (_cooldown > 0)
          Text('Resend in ${_cooldown}s',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral400))
        else
          GestureDetector(
            onTap: _isLoading ? null : onResend,
            child: const Text('Send a new code',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
      ]),
      const SizedBox(height: 24),
      // Listens to the code itself: OtpField repaints its own boxes, but the
      // button lives out here and would otherwise stay greyed out with six
      // digits sitting above it.
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => _primaryButton(
          label: 'Verify',
          enabled: value.text.length == 6 && !_isLoading,
          isLoading: _isLoading,
          onPressed: onVerify,
        ),
      ),
    ];
  }

  InputDecoration _deco({required String hint, required IconData icon}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 14),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _primaryButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.neutral300,
          disabledForegroundColor: AppColors.neutral500,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
