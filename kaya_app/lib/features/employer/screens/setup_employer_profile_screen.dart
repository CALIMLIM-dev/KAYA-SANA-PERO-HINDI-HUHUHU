import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/constants/employer_type.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../profile/screens/onboarding_verification_screen.dart';

/// Employer onboarding flow.
///
/// Both employer types use the same router entry, but the setup steps branch:
/// - Company: type, company details, logo, government ID, business registration, finish.
/// - Individual: type, name/details, photo, government ID, finish.
class SetupEmployerProfileScreen extends StatefulWidget {
  const SetupEmployerProfileScreen({super.key});

  @override
  State<SetupEmployerProfileScreen> createState() =>
      _SetupEmployerProfileScreenState();
}

class _SetupEmployerProfileScreenState extends State<SetupEmployerProfileScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  EmployerType? _selectedType;

  /// Structured location chosen from the picker.
  LocationModel? _selectedLocation;

  int _currentStep = 0;
  bool _isSaving = false;
  String? _tempImagePath; // Store image path in memory until Finish
  String _identityIdType = 'Philippine National ID';
  String? _identityIdPhotoPath;
  String? _identityIdPhotoName;
  String? _identitySelfiePath;
  String? _identitySelfieName;
  Map<String, dynamic>? _businessDocument;

  int get _totalSteps {
    if (_selectedType == EmployerType.company) return 4; // type, details, photo, business verification
    return 4; // type, details, photo, identity verification
  }

  bool get _isCompany => _selectedType == EmployerType.company;
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final verificationProvider = context.read<VerificationProvider>();
      await auth.fetchMe();
      await verificationProvider.fetchVerifications(); // Fetch verification status
      if (!mounted) return;

      // Only prefill if the user hasn't started typing — these awaits take a
      // moment, and overwriting mid-typing made the entered name disappear.
      if (_nameController.text.isEmpty) {
        _nameController.text = auth.user?['name'] as String? ?? '';
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _companyNameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() async {
    if (_currentStep == 0) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Profile Setup?'),
          content: const Text(
            'Your profile is not complete. If you leave now, all progress will be discarded.',
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
      ) ?? false;
      
      if (shouldExit && mounted) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    _goToStep(_currentStep - 1);
  }

  Future<void> _handlePrimaryAction() async {
    if (_isLastStep) {
      // ONLY save on finish
      final saved = await _saveAllProfileData();
      if (!saved) return;
      
      final employerProvider = context.read<EmployerProfileProvider>();
      final completed = await employerProvider.completeSetup();
      if (!completed) {
        _showError(employerProvider.errorMessage ?? 'Failed to complete setup');
        return;
      }
      
      await _finishSetup();
      return;
    }

    if (_currentStep == 0) {
      if (_selectedType == null) return;
      _goToStep(1);
      return;
    }

    // For step 1 (details), just validate and move forward - DON'T save yet
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
      _goToStep(_currentStep + 1);
      return;
    }

    // All other steps: just navigate
    _goToStep(_currentStep + 1);
  }

  // NEW: Save everything at once on Finish
  Future<bool> _saveAllProfileData() async {
    // No need to validate again - we already validated at step 1
    if (_selectedType == null) return false;

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final employerProvider = context.read<EmployerProfileProvider>();
    final verificationProvider = context.read<VerificationProvider>();

    try {
      // Removed validation that blocks incomplete verification - now truly optional
      final hasCompleteIdentity =
          _identityIdPhotoPath != null && _identitySelfiePath != null;

      // 1. Save name if individual
      if (_selectedType == EmployerType.individual) {
        final nameSaved = await auth.updateMe(name: _nameController.text.trim());
        if (!nameSaved) {
          _showError(auth.errorMessage ?? 'Failed to save your name');
          return false;
        }
      }

      // 2. Create employer profile
      final success = await employerProvider.createProfile(
        employerType: _selectedType!,
        companyName: _isCompany ? _companyNameController.text.trim() : null,
        industry: _isCompany ? _industryController.text.trim() : null,
        website: _isCompany && _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        locationId: _selectedLocation?.id,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );

      if (!success) {
        _showError(employerProvider.errorMessage ?? 'Failed to create profile');
        return false;
      }

      // 3. Upload photo if selected
      if (_tempImagePath != null) {
        final uploaded = await employerProvider.uploadImage(fromMemory: _tempImagePath);
        if (!uploaded) {
          _showError(employerProvider.errorMessage ?? 'Failed to upload image');
          return false;
        }
      }

      // 4. Submit verification drafts only after Finish (OPTIONAL - don't fail if error)
      if (hasCompleteIdentity) {
        try {
          await verificationProvider.submitGovernmentID(
            idType: _identityIdType,
            idPhotoPath: _identityIdPhotoPath!,
            selfiePhotoPath: _identitySelfiePath!,
          );
          // If verification upload fails, just continue - it's optional
        } catch (e) {
          print('Verification upload failed (optional): $e');
          // Don't stop the flow
        }
      }

      if (_isCompany && _businessDocument != null) {
        try {
          final bytes = _businessDocument!['documentBytes'] ?? _businessDocument!['bytes'];
          await verificationProvider.submitDocument(
            type: 'business_reg',
            fileName: (_businessDocument!['documentName'] ??
                _businessDocument!['name']) as String,
            filePath: (_businessDocument!['documentPath'] ??
                _businessDocument!['path']) as String?,
            fileBytes: bytes is List<int> ? bytes : (bytes as List?)?.cast<int>(),
          );
          // If verification upload fails, just continue - it's optional
        } catch (e) {
          print('Business verification upload failed (optional): $e');
          // Don't stop the flow
        }
      }

      await auth.fetchMe();
      return true;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);
    try {
      // Refreshing auth re-derives the home view: employer-only accounts land
      // on workers, while an account that now holds both profiles becomes
      // hybrid and sees jobs AND workers. No focus is forced here.
      await context.read<AuthProvider>().fetchMe();
      await context.read<EmployerProfileProvider>().fetchProfile();

      if (!mounted) return;

      // Navigate to home using Navigator directly, not AppRouter
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.home,
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String get _primaryLabel {
    if (_isLastStep) return 'Finish';
    if (_currentStep == 1) return 'Continue';
    return 'Next';
  }

  bool get _canContinue {
    if (_currentStep == 0) return _selectedType != null;
    return !_isSaving;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Profile Setup?'),
            content: const Text(
              'Your profile is not complete. If you leave now, all progress will be discarded.',
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
        ) ?? false;
        
        if (shouldExit && mounted) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: _previousStep,
        ),
        title: Text(
          'Step ${_currentStep + 1} of $_totalSteps',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.neutral200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildTypeStep(),
          _buildDetailsStep(),
          _buildPhotoStep(),
          if (!_isCompany) _buildIdentityVerificationStep(), // Only for individual
          if (_isCompany) _buildBusinessVerificationStep(), // Only for company
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business_center, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Set up your employer profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose whether you are hiring as a business or as an individual.',
            style: TextStyle(fontSize: 14, color: AppColors.neutral600),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeToggle(EmployerType.company),
                ),
                Expanded(
                  child: _buildTypeToggle(EmployerType.individual),
                ),
              ],
            ),
          ),
          if (_selectedType != null) ...[
            const SizedBox(height: 24),
            _buildInfoPanel(
              icon: _selectedType!.icon,
              title: _selectedType!.label,
              text: _selectedType == EmployerType.company
                  ? 'Businesses will submit company information and can upload a business permit, DTI certificate, or SEC registration.'
                  : 'Individuals will use their account name, location, photo, and government ID verification.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isCompany ? Icons.business : Icons.person,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _isCompany ? 'Business details' : 'Personal details',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCompany
                  ? 'Workers will see these details when they view your jobs.'
                  : 'Workers will see your name and location when you post jobs.',
              style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
            ),
            const SizedBox(height: 32),
            if (_isCompany) ...[
              _textField(
                controller: _companyNameController,
                label: 'Business Name *',
                hint: 'e.g., ABC Construction Co.',
                icon: Icons.business,
                requiredMessage: 'Business name is required',
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _industryController,
                label: 'Industry *',
                hint: 'e.g., Construction, Retail, Cleaning',
                icon: Icons.work_outline,
                requiredMessage: 'Industry is required',
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _websiteController,
                label: 'Website',
                hint: 'https://www.company.com',
                icon: Icons.language,
                keyboardType: TextInputType.url,
              ),
            ] else ...[
              _textField(
                controller: _nameController,
                label: 'Full Name *',
                hint: 'e.g., Juan Dela Cruz',
                icon: Icons.person,
                requiredMessage: 'Full name is required',
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 16),
            // Picker, not free text — keeps employer locations normalized so
            // they match job posts and worker locations.
            LocationPickerField(
              controller: _locationController,
              labelText: 'Location *',
              onSelected: (location) =>
                  setState(() => _selectedLocation = location),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Location is required' : null,
            ),
            const SizedBox(height: 16),
            _textField(
              controller: _descriptionController,
              label: _isCompany ? 'About the Business' : 'About You',
              hint: _isCompany
                  ? 'Tell workers about your business...'
                  : 'Tell workers what kind of help you usually need...',
              icon: Icons.info_outline,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStep() {
    // Use temp image path from memory
    final hasImage = _tempImagePath != null && _tempImagePath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isCompany ? Icons.add_business : Icons.add_a_photo,
            size: 64,
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          Text(
            _isCompany ? 'Add a business logo' : 'Add a profile photo',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A photo makes your job posts feel more trustworthy. You can skip this for now.',
            style: TextStyle(fontSize: 14, color: AppColors.neutral600),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: _isCompany ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _isCompany ? BorderRadius.circular(18) : null,
                    border: Border.all(
                      color: hasImage ? AppColors.success : AppColors.primary,
                      width: 3,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(_tempImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Icon(
                          _isCompany ? Icons.business : Icons.person,
                          size: 56,
                          color: AppColors.neutral400,
                        ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Pick image and store path in memory - DON'T upload
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (image != null && mounted) {
                      setState(() => _tempImagePath = image.path);
                    }
                  },
                  icon: Icon(hasImage ? Icons.edit : Icons.upload),
                  label: Text(hasImage ? 'Change Photo' : 'Upload Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityVerificationStep() {
    return _buildVerificationStep(
      icon: Icons.badge,
      title: 'Verify your identity',
      body:
          'Submit a valid Philippine government ID and selfie. This uses the same verification flow as worker profiles.',
      documentType: 'government_id',
      documentTitle: 'Valid Philippine ID',
      documentSubtitle: 'Government-issued ID with selfie',
    );
  }

  Widget _buildBusinessVerificationStep() {
    return _buildVerificationStep(
      icon: Icons.verified_user,
      title: 'Verify your business',
      body:
          'Upload a DTI certificate, SEC registration, or Mayor\'s Permit for admin review.',
      documentType: 'business_reg',
      documentTitle: 'Business Permit',
      documentSubtitle: 'DTI, SEC, or Mayor\'s Permit',
    );
  }

  Widget _buildVerificationStep({
    required IconData icon,
    required String title,
    required String body,
    required String documentType,
    required String documentTitle,
    required String documentSubtitle,
  }) {
    final isIdentity = documentType == 'government_id';
    final hasIdentityDraft =
        _identityIdPhotoPath != null && _identitySelfiePath != null;
    final hasBusinessDraft = _businessDocument != null;
    final hasDraft = isIdentity ? hasIdentityDraft : hasBusinessDraft;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildOnboardingVerificationCard(
            title: documentTitle,
            subtitle: documentSubtitle,
            icon: icon,
            isReady: hasDraft,
            onTap: () async {
              if (isIdentity) {
                // Use onboarding verification screen for government ID
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingVerificationScreen(
                      existingData: {
                        'idType': _identityIdType,
                        'idPhotoPath': _identityIdPhotoPath,
                        'idPhotoName': _identityIdPhotoName,
                        'selfiePhotoPath': _identitySelfiePath,
                        'selfiePhotoName': _identitySelfieName,
                      },
                    ),
                  ),
                );
                if (result == null || !mounted) return;
                setState(() {
                  _identityIdType = result['idType'] as String? ?? _identityIdType;
                  _identityIdPhotoPath = result['idPhotoPath'] as String?;
                  _identityIdPhotoName = result['idPhotoName'] as String?;
                  _identitySelfiePath = result['selfiePhotoPath'] as String?;
                  _identitySelfieName = result['selfiePhotoName'] as String?;
                });
              } else {
                // For business documents, use file picker directly
                final vp = context.read<VerificationProvider>();
                final result = await vp.pickDocument();
                if (result != null && mounted) {
                  setState(() {
                    _businessDocument = {
                      'documentPath': result['path'] as String?,
                      'documentName': result['name'] as String,
                      'documentBytes': result['bytes'],
                    };
                  });
                }
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Verification will be submitted when you tap Finish.',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isReady,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.neutral200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReady ? Icons.check_circle : icon,
                  color: isReady ? AppColors.success : AppColors.neutral600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    if (!isReady)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                  ],
                ),
              ),
              if (isReady)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.neutral400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // Allow skip on photo (step 2) and verification steps (step 3)
    final canSkip = _currentStep >= 2;
    
    // Hide skip button if user has captured verification photos/documents (in memory draft)
    final hasIdentityDraft = _identityIdPhotoPath != null && _identitySelfiePath != null;
    final hasBusinessDraft = _businessDocument != null;
    
    // Only check verification status on the verification step (step 3)
    bool showSkipButton = canSkip;
    if (_isLastStep) {
      final hasDraft = _isCompany ? hasBusinessDraft : hasIdentityDraft;
      showSkipButton = !hasDraft; // Hide skip if user captured photos/documents
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (showSkipButton) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () {
                    if (_isLastStep) {
                      // On last step, skip means finish without verification
                      _handlePrimaryAction();
                    } else {
                      _goToStep(_currentStep + 1);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                    side: const BorderSide(color: AppColors.neutral300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isLastStep ? 'Skip & Finish' : 'Skip'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _canContinue ? _handlePrimaryAction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.neutral300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _primaryLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(EmployerType type) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (_currentStep >= _totalSteps) _currentStep = _totalSteps - 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected ? Colors.white : AppColors.neutral600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? requiredMessage,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      ),
      validator: requiredMessage == null
          ? null
          : (value) {
              if (value == null || value.trim().isEmpty) {
                return requiredMessage;
              }
              if (value.trim().length < 2) {
                return 'Please enter at least 2 characters';
              }
              return null;
            },
    );
  }

  Widget _buildInfoPanel({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.neutral600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
