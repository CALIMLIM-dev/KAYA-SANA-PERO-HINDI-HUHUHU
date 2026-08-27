import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';

/// ONBOARDING ONLY - No API calls, returns Map<String, dynamic> with verification data
class OnboardingVerificationScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  
  const OnboardingVerificationScreen({
    super.key,
    this.existingData,
  });

  @override
  State<OnboardingVerificationScreen> createState() => _OnboardingVerificationScreenState();
}

class _OnboardingVerificationScreenState extends State<OnboardingVerificationScreen> {
  String _selectedIdType = 'Philippine National ID';
  final _customIdCtrl = TextEditingController();
  String? _idPhotoPath;
  String? _idPhotoName;
  String? _selfiePhotoPath;
  String? _selfiePhotoName;
  bool _confirmed = false;

  final _idTypes = [
    'Philippine National ID',
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

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _selectedIdType = widget.existingData!['idType'] as String? ?? 'Philippine National ID';
      _idPhotoPath = widget.existingData!['idPhotoPath'] as String?;
      _idPhotoName = widget.existingData!['idPhotoName'] as String?;
      _selfiePhotoPath = widget.existingData!['selfiePhotoPath'] as String?;
      _selfiePhotoName = widget.existingData!['selfiePhotoName'] as String?;
      _confirmed = widget.existingData!['confirmed'] as bool? ?? false;
      if (_selectedIdType == 'Other') {
        _customIdCtrl.text = widget.existingData!['customIdType'] as String? ?? '';
      }
    }
  }

  @override
  void dispose() {
    _customIdCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_selectedIdType == 'Other' && _customIdCtrl.text.trim().isEmpty) {
      return false;
    }
    return _idPhotoPath != null && _selfiePhotoPath != null && _confirmed;
  }

  Future<void> _capturePhoto(bool isIdPhoto) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      /*
          Sized down, or the upload never lands.

          A raw camera capture is several megabytes, and this sends two of
          them - the ID and the selfie - in one request. The server sits
          behind a 1MB body limit, so an uncompressed pair was refused before
          it was read, and the failure was swallowed as "verification is
          optional" - which is why submitting appeared to do nothing at all.

          Every other picker in the app already caps its output. The standalone
          verification screen uses these exact numbers; a 1024px ID photo at
          quality 70 is still perfectly readable and lands around 150KB.
      */
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    
    if (image != null) {
      setState(() {
        if (isIdPhoto) {
          _idPhotoPath = image.path;
          _idPhotoName = image.name;
        } else {
          _selfiePhotoPath = image.path;
          _selfiePhotoName = image.name;
        }
      });
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'idType': _selectedIdType == 'Other' ? _customIdCtrl.text.trim() : _selectedIdType,
      'customIdType': _selectedIdType == 'Other' ? _customIdCtrl.text.trim() : null,
      'idPhotoPath': _idPhotoPath,
      'idPhotoName': _idPhotoName,
      'selfiePhotoPath': _selfiePhotoPath,
      'selfiePhotoName': _selfiePhotoName,
      'confirmed': _confirmed,
    });
  }

  Future<void> _handleBackButton() async {
    // If user has captured any photos, show discard confirmation
    if (_idPhotoPath != null || _selfiePhotoPath != null) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Verification?'),
          content: const Text(
            'Your verification photos will be discarded. You can verify your identity later from your profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Discard',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      
      if (shouldDiscard == true && mounted) {
        Navigator.pop(context, null); // Return null to indicate discard
      }
    } else {
      // No photos captured, just go back
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
            onPressed: _handleBackButton,
          ),
          title: const Text(
            'Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Government ID Verification',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.neutral900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a valid government-issued ID to verify your identity',
                style: TextStyle(fontSize: 14, color: AppColors.neutral600),
              ),
              const SizedBox(height: 24),

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
                    isExpanded: true,
                    items: _idTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (val) => setState(() => _selectedIdType = val ?? 'Philippine National ID'),
                  ),
                ),
              ),
              
              if (_selectedIdType == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customIdCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
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
              
              // ID Photo Capture
              const Text('1. Capture Your ID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
              const SizedBox(height: 8),
              _buildCaptureBox(
                label: 'ID Photo',
                path: _idPhotoPath,
                name: _idPhotoName,
                onCapture: () => _capturePhoto(true),
                onClear: () => setState(() { _idPhotoPath = null; _idPhotoName = null; }),
              ),
              
              const SizedBox(height: 20),
              
              // Selfie with ID Capture
              const Text('2. Capture Selfie with ID', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
              const SizedBox(height: 4),
              const Text('Hold your ID next to your face', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
              const SizedBox(height: 8),
              _buildCaptureBox(
                label: 'Selfie with ID',
                path: _selfiePhotoPath,
                name: _selfiePhotoName,
                onCapture: () => _capturePhoto(false),
                onClear: () => setState(() { _selfiePhotoPath = null; _selfiePhotoName = null; }),
              ),

              if (_idPhotoPath != null && _selfiePhotoPath != null) ...[
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.neutral300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
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
}
