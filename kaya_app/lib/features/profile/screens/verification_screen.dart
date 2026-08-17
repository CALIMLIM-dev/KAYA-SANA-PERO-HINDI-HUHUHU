import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/verification_provider.dart';

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
  bool _emailSent = false;
  bool _emailVerified = false;

  // Document
  String? _docPath;
  String? _docName;
  List<int>? _docBytes;
  
  // Selfie with ID
  String? _selfiePath;
  String? _selfieName;
  
  // ID Type dropdown
  String? _selectedIdType;
  String? _customIdType;
  final _customIdCtrl = TextEditingController();
  
  bool _confirmed = false;
  bool _submitted = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _customIdCtrl.dispose();
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
    if (_phoneVerified) return _successState('Phone number verified!');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.phone_android, 'Verify Phone Number', subtitle),
          const SizedBox(height: 32),
          if (!_otpSent) ...[
            _label('Phone Number'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: _deco(hint: '+63 912 345 6789', icon: Icons.phone),
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Send OTP',
              enabled: _phoneCtrl.text.isNotEmpty && !_isLoading,
              onPressed: _sendOTP,
            ),
          ] else ...[
            _sentBanner('OTP sent to ${_phoneCtrl.text}',
                onTap: () => setState(() { _otpSent = false; _otpCtrl.clear(); })),
            const SizedBox(height: 24),
            _label('Enter the 6-digit OTP'),
            const SizedBox(height: 8),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
              decoration: _deco(hint: '------', icon: Icons.lock_outline),
            ),
            Row(children: [
              const Text("Didn't receive it? ", style: TextStyle(fontSize: 13, color: AppColors.neutral500)),
              GestureDetector(
                onTap: _sendOTP,
                child: const Text('Resend OTP',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Verify',
              enabled: _otpCtrl.text.length == 6 && !_isLoading,
              onPressed: _verifyOTP,
            ),
          ],
        ],
      ),
    );
  }

  // ── Email ─────────────────────────────────────────────────────────────────

  Widget _buildEmail(String subtitle) {
    if (_emailVerified) return _successState('Email address verified!');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.email_outlined, 'Verify Email Address', subtitle),
          const SizedBox(height: 32),
          if (!_emailSent) ...[
            _label('Email Address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: _deco(hint: 'your.email@example.com', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 24),
            _primaryButton(
              label: 'Send Verification Link',
              enabled: _emailCtrl.text.isNotEmpty && !_isLoading,
              onPressed: _sendEmail,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('Check your email',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
                const SizedBox(height: 8),
                Text('We sent a verification link to ${_emailCtrl.text}',
                    style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _primaryButton(
                  label: "I've verified my email",
                  enabled: true,
                  onPressed: () => setState(() => _emailVerified = true),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() { _emailSent = false; _emailCtrl.clear(); }),
                  child: const Text('Use a different email', style: TextStyle(color: AppColors.neutral500)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocument(BuildContext context, String type, String subtitle) {
    if (_submitted) return _successState('Document submitted for review!');

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
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    isBusiness 
                      ? 'DTI Certificate, SEC Registration, or Mayor\'s Permit'
                      : 'Valid document',
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral700, height: 1.5)
                  ),
                ],
              ),
            ),
            
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
                                      style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
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
                                      style: const TextStyle(fontSize: 13, color: AppColors.success),
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
                      style: TextStyle(fontSize: 13, color: AppColors.neutral700, height: 1.5),
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
                              style: const TextStyle(fontSize: 13, color: AppColors.success),
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

  Future<void> _captureFromCamera() async {
    final result = await context.read<VerificationProvider>().capturePhoto();
    if (result != null) {
      setState(() {
        _docPath  = result['path'] as String?;
        _docName  = result['name'] as String;
      });
    }
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
    
    bool success;
    if (type == 'government_id') {
      // Government ID needs both ID photo and selfie
      if (_docPath == null || _selfiePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please capture both ID and selfie photos'),
          backgroundColor: AppColors.error,
        ));
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
      success = await vp.submitDocument(
        type: type,
        fileName: _docName!,
        filePath: _docPath,
        fileBytes: _docBytes,
      );
    }
    
    if (!mounted) return;
    if (success) {
      setState(() => _submitted = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(vp.errorMessage ?? 'Submission failed'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);
    // TODO: wire to real SMS provider (Twilio/Vonage)
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { _isLoading = false; _otpSent = true; });
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _isLoading = false; _phoneVerified = true; });
  }

  Future<void> _sendEmail() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _isLoading = false; _emailSent = true; });
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900));

  Widget _sentBanner(String msg, {required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: AppColors.success))),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ),
      ]),
    );
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
