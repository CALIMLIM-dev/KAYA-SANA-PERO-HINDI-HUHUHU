import 'package:flutter/material.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';

/// Profile Setup Onboarding - Forced flow before home screen
/// JobStreet-style step-by-step profile completion
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Step 1: Basic Info
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = 'Both'; // Worker, Employer, or Both

  // Step 2: Location
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Step 3: Skills (Workers) / Company Info (Employers)
  final List<String> _selectedSkills = [];
  final List<String> _availableSkills = [
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Construction',
    'Cleaning',
    'AC Repair',
    'Welding',
    'Masonry',
  ];
  final TextEditingController _companyController = TextEditingController();
  int _yearsExperience = 0;

  // Step 4: Profile Photo
  bool _photoAdded = false;

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Complete setup and go to home
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToHome() {
    // For steps 3-5, allow skip
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
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
            : null,
        title: Column(
          children: [
            Text(
              'Complete Your Profile',
              style: TextStyle(
                color: AppColors.neutral900,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Step ${_currentStep + 1} of 5',
              style: TextStyle(
                color: AppColors.neutral600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentStep >= 2)
            TextButton(
              onPressed: _skipToHome,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 5,
            backgroundColor: AppColors.neutral200,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1BasicInfo(),
          _buildStep2Location(),
          _buildStep3SkillsOrCompany(),
          _buildStep4ProfilePhoto(),
          _buildStep5Verification(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
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
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _currentStep < 4 ? 'Continue' : 'Complete Setup',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Let\'s get started!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Role Selection
          Text(
            'I am a...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  icon: Icons.construction,
                  label: 'Worker',
                  subtitle: 'Looking for jobs',
                  isSelected: _selectedRole == 'Worker',
                  onTap: () => setState(() => _selectedRole = 'Worker'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  icon: Icons.business_center,
                  label: 'Employer',
                  subtitle: 'Hiring workers',
                  isSelected: _selectedRole == 'Employer',
                  onTap: () => setState(() => _selectedRole = 'Employer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Both option
          _RoleCard(
            icon: Icons.people,
            label: 'Both',
            subtitle: 'I want to find jobs AND hire workers',
            isSelected: _selectedRole == 'Both',
            onTap: () => setState(() => _selectedRole = 'Both'),
          ),
          
          const SizedBox(height: 24),
          
          // Full Name
          Text(
            'Full Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              hintText: 'Juan Dela Cruz',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Phone Number
          Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+63 912 345 6789',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Where are you located?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps match you with nearby opportunities',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Use My Location button
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement location picker
              AppToast.info(context, 'Location picker coming soon');
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Use Current Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // City
          Text(
            'City/Municipality',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          LocationPickerField(
                      controller: _cityController,
                      labelText: 'City',
                      onSelected: (_) => setState(() {}),
                    ),
          
          const SizedBox(height: 16),
          
          // Address
          Text(
            'Barangay / Street Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your complete address',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SkillsOrCompany() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            _selectedRole == 'Worker' ? 'Your Skills' : 'Company Information',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedRole == 'Worker'
                ? 'What services can you offer?'
                : 'Tell us about your business',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          if (_selectedRole == 'Worker' || _selectedRole == 'Both') ...[
            // Skills - Chip selection
            Text(
              'Primary Skills',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSkills.map((skill) {
                final isSelected = _selectedSkills.contains(skill);
                return FilterChip(
                  label: Text(skill),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSkills.add(skill);
                      } else {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.neutral700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Years of Experience - Stepper
            Text(
              'Years of Experience',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: Row(
                children: [
                  Icon(Icons.timeline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_yearsExperience ${_yearsExperience == 1 ? 'year' : 'years'}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutral900,
                          ),
                        ),
                        Slider(
                          value: _yearsExperience.toDouble(),
                          min: 0,
                          max: 30,
                          divisions: 30,
                          label: '$_yearsExperience years',
                          onChanged: (value) {
                            setState(() {
                              _yearsExperience = value.toInt();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _yearsExperience > 0
                        ? () => setState(() => _yearsExperience--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _yearsExperience < 30
                        ? () => setState(() => _yearsExperience++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ] else if (_selectedRole == 'Employer') ...[
            // Company Name (Optional)
            Row(
              children: [
                Text(
                  'Company Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _companyController,
              decoration: InputDecoration(
                hintText: 'Your business name',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.business, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.neutral300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.neutral300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can add more details later in your profile',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.neutral700,
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

  Widget _buildStep4ProfilePhoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            'Add a profile photo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Profiles with photos get 5x more responses',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.neutral600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // Photo Upload Area
          GestureDetector(
            onTap: () => setState(() => _photoAdded = !_photoAdded),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: _photoAdded 
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.neutral200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _photoAdded ? AppColors.success : AppColors.neutral300,
                  width: 3,
                ),
              ),
              child: _photoAdded
                  ? Icon(Icons.check_circle, size: 64, color: AppColors.success)
                  : Icon(Icons.add_a_photo, size: 48, color: AppColors.neutral500),
            ),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: () => setState(() => _photoAdded = true),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          OutlinedButton.icon(
            onPressed: () => setState(() => _photoAdded = true),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose from Gallery'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Verification() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.verified_user,
            size: 80,
            color: AppColors.success,
          ),
          const SizedBox(height: 24),
          Text(
            'Get verified!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Stand out with a verified badge',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.neutral600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Benefits
          _VerificationBenefit(
            icon: Icons.security,
            title: 'Build Trust',
            subtitle: 'Verified profiles are more trusted by employers',
          ),
          const SizedBox(height: 16),
          _VerificationBenefit(
            icon: Icons.trending_up,
            title: '3x More Opportunities',
            subtitle: 'Verified workers get more job invitations',
          ),
          const SizedBox(height: 16),
          _VerificationBenefit(
            icon: Icons.star,
            title: 'Priority Listings',
            subtitle: 'Your profile appears higher in search results',
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verification can be completed later from your profile settings',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.neutral700,
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
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.neutral300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppColors.primary : AppColors.neutral600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.neutral600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _VerificationBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.neutral600,
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
