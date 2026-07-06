import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../data/models/skill_model.dart';
import '../../../data/services/api_client.dart';
import '../../../core/navigation/app_router.dart';

/// Worker Profile Setup Flow - 6 Step Onboarding
/// 
/// Steps:
/// 1. Location (required)
/// 2. Category + Skills (required)
/// 3. Experience (optional)
/// 4. Certifications (optional)
/// 5. Profile Photo (optional)
/// 6. Verification (optional)
class WorkerSetupFlowScreen extends StatefulWidget {
  final int resumeStep;
  
  const WorkerSetupFlowScreen({super.key, this.resumeStep = 0});

  @override
  State<WorkerSetupFlowScreen> createState() => _WorkerSetupFlowScreenState();
}

class _WorkerSetupFlowScreenState extends State<WorkerSetupFlowScreen> {
  late PageController _pageController;
  late int _currentStep;
  late TextEditingController _locationController;
  late TextEditingController _nameController;
  
  // Form data
  String? _location;
  String? _userName;
  List<SkillModel> _selectedSkills = [];
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _currentStep = widget.resumeStep;
    _pageController = PageController(initialPage: widget.resumeStep);
    
    // Initialize controllers FIRST to avoid red error
    _locationController = TextEditingController();
    _nameController = TextEditingController();
    
    // Load existing data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final provider = context.read<WorkerProfileProvider>();
      final verificationProvider = context.read<VerificationProvider>();
      
      // Fetch fresh data
      await authProvider.fetchMe();
      await provider.fetchProfile();
      await provider.fetchCategories();
      await verificationProvider.fetchVerifications();
      
      _userName = authProvider.user?['name'] as String?;
      _location = provider.location;
      
      // Update controllers with fetched data
      _nameController.text = _userName ?? '';
      _locationController.text = _location ?? '';
      
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _locationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 6) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipStep() {
    // Skip optional steps
    if (_currentStep >= 2) {
      _nextStep();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _finishSetup() async {
    // Refresh auth to update completion flags
    await context.read<AuthProvider>().fetchMe();
    
    if (mounted) {
      // Navigate to home
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.home,
        (route) => false,
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: // Location + Name - Check controllers directly
        return _nameController.text.trim().isNotEmpty && 
               _locationController.text.trim().isNotEmpty;
      case 1: // Skills
        return _selectedSkills.isNotEmpty;
      default:
        return true; // Optional steps can always proceed
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = 7;
    final progress = (_currentStep + 1) / totalSteps;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
                onPressed: _previousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.neutral900),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Step ${_currentStep + 1} of $totalSteps',
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
            backgroundColor: AppColors.neutral200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentStep = page),
        children: [
          _buildLocationStep(),
          _buildSkillsStep(),
          _buildExperienceStep(),
          _buildCertificationsStep(),
          _buildLicensesStep(),
          _buildPhotoStep(),
          _buildVerificationStep(),
        ],
      ),
      bottomNavigationBar: _isSaving ? null : _buildBottomBar(),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let employers know who you are and where you work.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Name (EDITABLE)
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              _userName = value;
              setState(() {}); // Need setState to update button state
            },
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'Enter your full name',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Location input
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              _location = value;
              setState(() {}); // Need setState to update button state
            },
            decoration: InputDecoration(
              labelText: 'City or Municipality *',
              hintText: 'e.g., Manila, Quezon City',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsStep() {
    final provider = context.watch<WorkerProfileProvider>();
    
    // Group skills by category for display
    final Map<String, List<SkillModel>> groupedSkills = {};
    for (var skill in _selectedSkills) {
      // Find category name from provider's categories list
      String categoryName = 'Other';
      try {
        final category = provider.categories.firstWhere((c) => c.id == skill.categoryId);
        categoryName = category.name;
      } catch (e) {
        // Category not found, use 'Other'
      }
      groupedSkills.putIfAbsent(categoryName, () => []).add(skill);
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.build_circle, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          const Text(
            'What are your skills?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your category and skills. This helps employers find you.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Selected skills preview with categories
          if (_selectedSkills.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Selected Skills',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedSkills.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Show grouped by category
                  ...groupedSkills.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((skill) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                skill.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Add skills button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRouter.addSkills,
                  arguments: <String>[],
                );
                if (result != null && result is List<SkillModel> && mounted) {
                  setState(() => _selectedSkills = result);
                }
              },
              icon: Icon(_selectedSkills.isEmpty ? Icons.add : Icons.edit, size: 20),
              label: Text(_selectedSkills.isEmpty ? 'Add Skills' : 'Edit Skills'),
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
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    final provider = context.watch<WorkerProfileProvider>();
    final experiences = provider.experiencesNew;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.work, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Work Experience',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your work history to stand out. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Experience preview
          if (experiences.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Experience',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${experiences.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...experiences.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exp = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp.jobTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    exp.companyName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDate(exp.startDate)} - ${exp.isCurrent ? 'Present' : _formatDate(exp.endDate)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.neutral500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRouter.addExperience);
                if (mounted) {
                  await context.read<WorkerProfileProvider>().fetchExperiences();
                  setState(() {});
                }
              },
              icon: Icon(experiences.isEmpty ? Icons.add : Icons.edit, size: 20),
              label: Text(experiences.isEmpty ? 'Add Experience' : 'Manage Experience'),
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
        ],
      ),
    );
  }

  Widget _buildCertificationsStep() {
    final provider = context.watch<WorkerProfileProvider>();
    final certifications = provider.certifications;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified, size: 64, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            'Certifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add professional certifications to boost your profile. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Certifications preview
          if (certifications.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Certifications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${certifications.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...certifications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cert = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cert.certificationName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cert.issuingOrganization,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  if (cert.issueDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issued: ${_formatDate(cert.issueDate.toString())}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.neutral500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRouter.addCertifications);
                if (mounted) {
                  await context.read<WorkerProfileProvider>().fetchCertifications();
                  setState(() {});
                }
              },
              icon: Icon(certifications.isEmpty ? Icons.add : Icons.edit, size: 20),
              label: Text(certifications.isEmpty ? 'Add Certifications' : 'Manage Certifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicensesStep() {
    final provider = context.watch<WorkerProfileProvider>();
    final licenses = provider.licenses;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_membership, size: 64, color: AppColors.warning),
          const SizedBox(height: 24),
          const Text(
            'Licenses',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add professional licenses (PRC, drivers license, etc.). (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Licenses preview
          if (licenses.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Licenses',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${licenses.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...licenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final license = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    license.licenseName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    license.issuingAuthority,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  if (license.issueDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issued: ${_formatDate(license.issueDate.toString())}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.neutral500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRouter.addLicenses);
                if (mounted) {
                  await context.read<WorkerProfileProvider>().fetchLicenses();
                  setState(() {});
                }
              },
              icon: Icon(licenses.isEmpty ? Icons.add : Icons.edit, size: 20),
              label: Text(licenses.isEmpty ? 'Add Licenses' : 'Manage Licenses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    final provider = context.watch<WorkerProfileProvider>();
    final hasPhoto = provider.profilePhotoPath != null && provider.profilePhotoPath!.isNotEmpty;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.camera_alt, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          const Text(
            'Add a profile photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profiles with photos get 5x more views! (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: hasPhoto ? Colors.transparent : AppColors.neutral200,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPhoto ? AppColors.success : AppColors.primary,
                      width: 3,
                    ),
                    image: hasPhoto
                        ? DecorationImage(
                            image: NetworkImage(
                              ApiClient.fileUrl(provider.profilePhotoPath!),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person,
                          size: 60,
                          color: AppColors.neutral400,
                        ),
                ),
                const SizedBox(height: 16),
                if (hasPhoto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Photo uploaded',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final choice = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Choose Photo'),
                        content: const Text('Select photo source'),
                        actions: [
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ],
                      ),
                    );
                    if (choice != null && mounted) {
                      await provider.uploadPhoto(fromCamera: choice);
                      if (mounted) setState(() {});
                    }
                  },
                  icon: Icon(hasPhoto ? Icons.edit : Icons.add_a_photo),
                  label: Text(hasPhoto ? 'Change Photo' : 'Upload Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildVerificationStep() {
    final verificationProvider = context.watch<VerificationProvider>();
    final hasVerification = verificationProvider.verifications.isNotEmpty;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Verify Your Identity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get verified to increase trust and unlock more opportunities. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Verification status - EXPANDED UI
          if (hasVerification) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verification Submitted!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${(verificationProvider.verifications.first['status'] ?? 'pending').toString().toUpperCase()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline, size: 24, color: AppColors.primary),
                        SizedBox(height: 8),
                        Text(
                          'Your verification is being reviewed by our team. You\'ll be notified once approved.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutral700,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // No verification yet - show upload button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/verification');
                  if (mounted) {
                    await verificationProvider.fetchVerifications();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text('Upload ID'),
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
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 6;
    final isOptionalStep = _currentStep >= 2;
    
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
            // Skip button (only on optional steps)
            if (isOptionalStep) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _skipStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                    side: BorderSide(color: AppColors.neutral300),
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
            
            // Next/Finish button
            Expanded(
              flex: isOptionalStep ? 1 : 1,
              child: ElevatedButton(
                onPressed: (_canProceed && !_isSaving)
                    ? () async {
                        setState(() => _isSaving = true);
                        try {
                          // Save current step data
                          await _saveCurrentStep();
                          
                          // Move to next step or finish
                          if (isLastStep) {
                            await _finishSetup();
                          } else {
                            _nextStep();
                          }
                        } catch (e) {
                          // Error already shown in _saveCurrentStep
                          print('Save error: $e');
                        } finally {
                          if (mounted) {
                            setState(() => _isSaving = false);
                          }
                        }
                      }
                    : null,
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
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isLastStep ? 'Finish' : 'Next',
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

  Future<void> _saveCurrentStep() async {
    final provider = context.read<WorkerProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    
    switch (_currentStep) {
      case 0: // Name + Location
        // Get values from controllers
        final name = _nameController.text.trim();
        final location = _locationController.text.trim();
        
        // Save name to users table
        if (name.isNotEmpty) {
          await authProvider.updateMe(name: name);
        }
        
        // Save location to worker profile
        if (location.isNotEmpty) {
          final success = await provider.updateLocation(location);
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage ?? 'Failed to save location'),
                backgroundColor: AppColors.error,
              ),
            );
            throw Exception('Save failed');
          }
        }
        break;
      case 1: // Skills
        if (_selectedSkills.isNotEmpty) {
          await provider.saveSkillsWithCategories(_selectedSkills);
          // Add delay to ensure save completes
          await Future.delayed(const Duration(milliseconds: 500));
          // Verify save was successful by refetching
          await provider.fetchSkills();
          if (provider.skills.isEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save skills. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
            throw Exception('Skills save failed');
          }
        }
        break;
      // Other steps save through their own screens
      default:
        break;
    }
  }
}
