import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../data/models/employer_verification_model.dart';
import 'edit_company_profile_screen.dart';

/// Company Profile Screen
/// 
/// COMPLETELY SEPARATE from Individual Profile — NO CONDITIONALS
/// Shows company-specific fields: company_name, industry, website, description, location
class CompanyProfileScreen extends StatelessWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Company Info
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Consumer2<EmployerProfileProvider, AuthProvider>(
                builder: (context, provider, auth, _) {
                  final profile = provider.profile!; // Safe because router checks null
                  
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company Logo
                            GestureDetector(
                              onTap: () => _uploadImage(context, provider),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  image: profile.imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(profile.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: profile.imageUrl == null
                                    ? const Icon(
                                        Icons.business,
                                        color: AppColors.primary,
                                        size: 32,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Company Name
                            Text(
                              profile.companyName ?? 'Company Name',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            
                            const SizedBox(height: 4),
                            
                            // Industry
                            if (profile.industry != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  profile.industry!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Profile Content
          SliverToBoxAdapter(
            child: Consumer<EmployerProfileProvider>(
              builder: (context, provider, _) {
                final profile = provider.profile!;
                final verification = provider.verification!;
                
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verification Status
                      _buildVerificationCard(verification),
                      
                      const SizedBox(height: 16),
                      _buildSectionHeader('Verifications'),
                      const SizedBox(height: 12),
                      Consumer<VerificationProvider>(
                        builder: (context, vp, _) {
                          return Column(
                            children: [
                              _buildVerificationActionCard(
                                context: context,
                                title: 'Valid Philippine ID',
                                subtitle: 'Government-issued ID with selfie',
                                icon: Icons.badge,
                                type: 'government_id',
                                status: vp.statusFor('government_id'),
                              ),
                              _buildVerificationActionCard(
                                context: context,
                                title: 'Business Permit',
                                subtitle: 'DTI, SEC, or Mayor\'s Permit',
                                icon: Icons.business_center,
                                type: 'business_reg',
                                status: vp.statusFor('business_reg'),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Company Details
                      _buildSectionHeader('Company Information'),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.business,
                        label: 'Company Name',
                        value: profile.companyName,
                        placeholder: 'Add company name',
                        onTap: () => _navigateToEdit(context, profile),
                      ),
                      _buildInfoCard(
                        icon: Icons.work_outline,
                        label: 'Industry',
                        value: profile.industry,
                        placeholder: 'Add industry',
                        onTap: () => _navigateToEdit(context, profile),
                      ),
                      _buildInfoCard(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: profile.location,
                        placeholder: 'Add location',
                        onTap: () => _navigateToEdit(context, profile),
                      ),
                      _buildInfoCard(
                        icon: Icons.language,
                        label: 'Website',
                        value: profile.website,
                        placeholder: 'Add website',
                        onTap: () => _navigateToEdit(context, profile),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // About Company
                      _buildSectionHeader('About the Company'),
                      const SizedBox(height: 12),
                      _buildDescriptionCard(
                        description: profile.description,
                        placeholder: 'Tell workers about your company',
                        onTap: () => _navigateToEdit(context, profile),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(EmployerVerification verification) {
    final isVerified = verification.fullyVerified;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified 
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? AppColors.success : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.info_outline,
            color: isVerified ? AppColors.success : AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Verified Company' : 'Verification Pending',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  verification.statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isVerified ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          if (!isVerified)
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.warning,
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required String status,
  }) {
    final isVerified = status == 'verified';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    final color = isVerified
        ? AppColors.success
        : isPending
            ? AppColors.warning
            : isRejected
                ? AppColors.error
                : AppColors.neutral600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: isVerified
              ? null
              : () async {
                  await Navigator.pushNamed(
                    context,
                    '/verification',
                    arguments: {
                      'type': type,
                      'title': title,
                      'subtitle': subtitle,
                    },
                  );
                  if (context.mounted) {
                    context.read<VerificationProvider>().fetchVerifications();
                    context.read<EmployerProfileProvider>().fetchProfile();
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.check_circle
                        : isPending
                            ? Icons.hourglass_top
                            : isRejected
                                ? Icons.error_outline
                                : icon,
                    color: color,
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
                      Text(
                        isVerified
                            ? 'Verified'
                            : isPending
                                ? 'Under admin review'
                                : isRejected
                                    ? 'Rejected - tap to resubmit'
                                    : subtitle,
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                ),
                if (isVerified || isPending || isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVerified
                          ? 'Verified'
                          : isPending
                              ? 'Pending'
                              : 'Retake',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.neutral900,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasValue ? value : placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                          color: hasValue ? AppColors.neutral900 : AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.neutral400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard({
    required String? description,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = description != null && description.isNotEmpty;
    
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasValue ? description : placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue ? AppColors.neutral900 : AppColors.neutral400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.neutral400,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadImage(BuildContext context, EmployerProfileProvider provider) async {
    final success = await provider.uploadImage();
    
    if (!success && provider.errorMessage != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
      }
    }
  }

  void _navigateToEdit(BuildContext context, profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCompanyProfileScreen(profile: profile),
      ),
    );
  }
}
