import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/employer_type.dart';
import '../../../core/navigation/app_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/verification_provider.dart';

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
  int _currentStep = 0;
  bool _isSaving = false;

  int get _totalSteps {
    if (_selectedType == EmployerType.company) return 6;
    return 5;
  }

  bool get _isCompany => _selectedType == EmployerType.company;
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.fetchMe();
      _nameController.text = auth.user?['name'] as String? ?? '';
      if (mounted) setState(() {});
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

  void _previousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    _goToStep(_currentStep - 1);
  }

  Future<void> _handlePrimaryAction() async {
    if (_isLastStep) {
      await _finishSetup();
      return;
    }

    if (_currentStep == 0) {
      if (_selectedType == null) return;
      _goToStep(1);
      return;
    }

    if (_currentStep == 1) {
      await _saveProfileDetails();
      return;
    }

    _goToStep(_currentStep + 1);
  }

  Future<void> _saveProfileDetails() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) return;

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final employerProvider = context.read<EmployerProfileProvider>();

    try {
      if (_selectedType == EmployerType.individual) {
        final nameSaved = await auth.updateMe(name: _nameController.text.trim());
        if (!nameSaved) {
          _showError(auth.errorMessage ?? 'Failed to save your name');
          return;
        }
      }

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
      );

      if (!success) {
        _showError(employerProvider.errorMessage ?? 'Failed to create profile');
        return;
      }

      await auth.fetchMe();
      if (!mounted) return;
      _goToStep(2);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().fetchMe();
      await context.read<EmployerProfileProvider>().fetchProfile();
      if (!mounted) return;
      AppRouter.toHome(context);
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
    if (_currentStep == 1) return 'Save & Continue';
    return 'Next';
  }

  bool get _canContinue {
    if (_currentStep == 0) return _selectedType != null;
    return !_isSaving;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
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
          _buildIdentityVerificationStep(),
          if (_isCompany) _buildBusinessVerificationStep(),
          _buildFinishStep(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
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
            _textField(
              controller: _locationController,
              label: 'Location *',
              hint: 'e.g., Quezon City, Philippines',
              icon: Icons.location_on_outlined,
              requiredMessage: 'Location is required',
              textCapitalization: TextCapitalization.words,
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
    return Consumer<EmployerProfileProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;
        final hasImage = profile?.imageUrl != null && profile!.imageUrl!.isNotEmpty;

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
                                image: NetworkImage(profile.imageUrl!),
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
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final success = await provider.uploadImage();
                              if (!success && mounted) {
                                _showError(provider.errorMessage ?? 'Upload failed');
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
      },
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
    return Consumer<VerificationProvider>(
      builder: (context, verificationProvider, _) {
        final status = verificationProvider.statusFor(documentType);
        final submitted = status == 'pending' || status == 'verified';

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
              _buildStatusPanel(status),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/verification',
                      arguments: {
                        'type': documentType,
                        'title': documentTitle,
                        'subtitle': documentSubtitle,
                      },
                    );
                    if (!mounted) return;
                    await verificationProvider.fetchVerifications();
                    await context.read<EmployerProfileProvider>().fetchProfile();
                  },
                  icon: Icon(submitted ? Icons.refresh : Icons.upload_file),
                  label: Text(submitted ? 'Retake Verification' : 'Upload Document'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can continue setup while admin review is pending.',
                style: TextStyle(fontSize: 12, color: AppColors.neutral500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinishStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            'Employer profile ready',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'After finishing, you will return to the home screen where job categories and posting flows are available.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoPanel(
            icon: Icons.category,
            title: 'Next: choose a job category',
            text:
                'Use the home screen categories to browse workers or start creating a job post.',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canSkip = _currentStep >= 2 && !_isLastStep;

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
            if (canSkip) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _goToStep(_currentStep + 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                    side: const BorderSide(color: AppColors.neutral300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Skip'),
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

  Widget _buildStatusPanel(String status) {
    final isVerified = status == 'verified';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    final color = isVerified
        ? AppColors.success
        : isRejected
            ? AppColors.error
            : isPending
                ? AppColors.warning
                : AppColors.neutral600;

    final icon = isVerified
        ? Icons.check_circle
        : isRejected
            ? Icons.error_outline
            : isPending
                ? Icons.hourglass_top
                : Icons.info_outline;

    final label = isVerified
        ? 'Verified'
        : isRejected
            ? 'Rejected - submit again'
            : isPending
                ? 'Under admin review'
                : 'Not submitted';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
