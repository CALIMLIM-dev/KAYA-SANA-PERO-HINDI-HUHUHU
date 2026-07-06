import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/api_client.dart';
import '../../../data/models/worker_skill_model.dart';
import '../../../data/models/skill_model.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/verification_provider.dart';

/// My Worker Profile - JobStreet-inspired card layout
/// Shows filled data in cards, NOT empty clickable placeholders
class MyWorkerProfileScreen extends StatefulWidget {
  const MyWorkerProfileScreen({super.key});

  @override
  State<MyWorkerProfileScreen> createState() => _MyWorkerProfileScreenState();
}

class _MyWorkerProfileScreenState extends State<MyWorkerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Profile data read from WorkerProfileProvider — no local state needed
  // These getters proxy to the provider for display

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<WorkerProfileProvider>().fetchProfile().catchError((e) {
            print('Error fetching worker profile: $e');
          });
          context.read<VerificationProvider>().fetchVerifications().catchError((e) {
            print('Error fetching verifications: $e');
          });
        } catch (e) {
          print('Error in initState: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 56),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile Photo
                              GestureDetector(
                                onTap: () async {
                                  final provider = context.read<WorkerProfileProvider>();
                                  final choice = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Profile Photo'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Gallery'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Camera'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (choice == null) return;
                                  await provider.uploadPhoto(fromCamera: choice);
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: context.watch<WorkerProfileProvider>().profilePhotoPath != null
                                            ? Image.network(
                                                ApiClient.fileUrl(context.watch<WorkerProfileProvider>().profilePhotoPath),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.person, color: Colors.white54, size: 32),
                                              )
                                            : const Icon(Icons.camera_alt, color: Colors.white54, size: 24),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.add, size: 13, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Name — always visible
                                    Text(
                                      context.watch<WorkerProfileProvider>().name ?? 'Add your name',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: context.watch<WorkerProfileProvider>().name != null
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Location — always visible
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 13,
                                          color: context.watch<WorkerProfileProvider>().location != null
                                              ? Colors.white70
                                              : Colors.white30,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          context.watch<WorkerProfileProvider>().location ?? 'Add location',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.watch<WorkerProfileProvider>().location != null
                                                ? Colors.white70
                                                : Colors.white30,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Contact info
                                    Builder(builder: (context) {
                                      final p = context.watch<WorkerProfileProvider>();
                                      final hasPhone = p.phone != null && p.phone!.isNotEmpty;
                                      final hasEmail = p.email != null && p.email!.isNotEmpty;
                                      
                                      if (!hasPhone && !hasEmail) {
                                        return const Text('Add contact details',
                                            style: TextStyle(fontSize: 12, color: Colors.white24));
                                      }
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (hasPhone)
                                            Row(
                                              children: [
                                                const Icon(Icons.phone, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Text(p.phone!,
                                                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                              ],
                                            ),
                                          if (hasEmail)
                                            Row(
                                              children: [
                                                const Icon(Icons.email, size: 12, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Text(p.email!,
                                                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                              ],
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Skills preview - Grouped by category
                          Selector<WorkerProfileProvider, List<WorkerSkillModel>>(
                            selector: (_, provider) => provider.skills,
                            shouldRebuild: (prev, next) => prev.length != next.length,
                            builder: (context, skills, _) {
                              if (skills.isNotEmpty) {
                                // Group skills by category
                                final Map<String, List<WorkerSkillModel>> grouped = {};
                                for (var skill in skills) {
                                  final category = skill.categoryName ?? 'Other';
                                  grouped.putIfAbsent(category, () => []).add(skill);
                                }

                                return Container(
                                  constraints: const BoxConstraints(maxHeight: 80),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: grouped.entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Category header
                                              Text(
                                                entry.key.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white70,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Skills
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: entry.value.map((skill) => Container(
                                                  key: ValueKey(skill.id ?? skill.skillName),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    skill.skillName,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility, size: 13, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text(
                                        'Set your profile visibility',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.neutral600,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Profile'),
                    Tab(text: 'Verifications'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSuggestedTab(),
            _buildVerificationsTab(),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      if (d.contains('-')) {
        final parts = d.split('-');
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final m = int.tryParse(parts[1]) ?? 1;
        return '${months[m]} ${parts[0]}';
      }
    } catch (_) {}
    return d;
  }

  Widget _buildSuggestedTab() {
    final p = context.watch<WorkerProfileProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 16),

        // Name Card
        _buildInfoCard(
          title: 'Full Name',
          icon: Icons.person,
          iconColor: AppColors.primary,
          content: p.name != null
              ? Text(p.name!, style: const TextStyle(fontSize: 14, color: AppColors.neutral900))
              : const Text('Add your full name', style: TextStyle(color: AppColors.neutral600)),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/add-name',
                arguments: context.read<WorkerProfileProvider>().name);
            if (result != null && result is String && mounted) {
              final success = await context.read<WorkerProfileProvider>().updateName(result);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.read<WorkerProfileProvider>().errorMessage ?? 'Failed to save'),
                  backgroundColor: AppColors.error,
                ));
              }
            }
          },
        ),

        // Location Card
        _buildInfoCard(
          title: 'Location',
          icon: Icons.location_on,
          iconColor: AppColors.success,
          content: p.location != null
              ? Text(p.location!, style: const TextStyle(fontSize: 14, color: AppColors.neutral900))
              : const Text('Add your location', style: TextStyle(color: AppColors.neutral600)),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/add-location',
                arguments: context.read<WorkerProfileProvider>().location);
            if (result != null && result is String && mounted) {
              final success = await context.read<WorkerProfileProvider>().updateLocation(result);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.read<WorkerProfileProvider>().errorMessage ?? 'Failed to save'),
                  backgroundColor: AppColors.error,
                ));
              }
            }
          },
        ),

        // Personal Details Card
        _buildInfoCard(
          title: 'Personal Details',
          icon: Icons.contact_page,
          iconColor: AppColors.primary,
          content: p.phone != null || p.email != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.phone != null)
                      Text('Phone: ${p.phone}', style: const TextStyle(fontSize: 14)),
                    if (p.email != null)
                      Text('Email: ${p.email}', style: const TextStyle(fontSize: 14)),
                  ],
                )
              : const Text('Add your contact details', style: TextStyle(color: AppColors.neutral600)),
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/add-personal-details',
                arguments: {
                  'phone': context.read<WorkerProfileProvider>().phone,
                  'email': context.read<WorkerProfileProvider>().email,
                });
            if (result != null && result is Map && mounted) {
              final phone = result['phone'] as String?;
              final email = result['email'] as String?;
              final provider = context.read<WorkerProfileProvider>();
              if (phone != null) await provider.updatePhone(phone);
              if (email != null) {
                provider.email = email;
                provider.clearError(); // triggers rebuild
              }
            }
          },
        ),

        // Skills Card - Using Selector to prevent unnecessary rebuilds
        Selector<WorkerProfileProvider, List<WorkerSkillModel>>(
          selector: (_, provider) => provider.skills,
          shouldRebuild: (prev, next) => prev.length != next.length,
          builder: (context, skills, _) {
            final hasSkills = skills.isNotEmpty;
            
            // Group skills by category
            final Map<String, List<WorkerSkillModel>> grouped = {};
            for (var skill in skills) {
              final category = skill.categoryName ?? 'Other';
              grouped.putIfAbsent(category, () => []).add(skill);
            }
            
            return _buildInfoCard(
              title: 'Skills',
              icon: Icons.build_circle,
              iconColor: AppColors.accent,
              content: hasSkills
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category header
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
                              // Skills in this category
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.value.map((skill) => Container(
                                  key: ValueKey(skill.id ?? skill.skillName),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(skill.skillName, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          // Show confirmation dialog
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Remove Skill'),
                                              content: Text('Remove "${skill.skillName}" from your skills?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Remove'),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirmed == true && mounted && skill.id != null) {
                                            // Delete the specific skill by ID
                                            final provider = context.read<WorkerProfileProvider>();
                                            await provider.deleteSkill(skill.id!);
                                          }
                                        },
                                        child: Icon(Icons.close, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : const Text('Add your skills', style: TextStyle(color: AppColors.neutral600)),
              onTap: () async {
                final skillNames = skills.map((s) => s.skillName).toList();
                final result = await Navigator.pushNamed(context, '/add-skills', 
                    arguments: skillNames);
                if (result != null && result is List<SkillModel> && mounted) {
                  // Save skills with category info
                  await context.read<WorkerProfileProvider>().saveSkillsWithCategories(result);
                }
              },
            );
          },
        ),

        // Experience Card
        _buildInfoCard(
          title: 'Experience',
          icon: Icons.work,
          iconColor: AppColors.success,
          content: p.experiences.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.experiences.map((exp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp['title'] ?? exp['position'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text('${exp['company']} • ${_fmtDate(exp['start_date'])} – ${exp['end_date'] != null ? _fmtDate(exp['end_date']) : 'Present'}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add your experience', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-experience'),
        ),

        // Certifications Card
        _buildInfoCard(
          title: 'Certifications',
          icon: Icons.workspace_premium,
          iconColor: Colors.orange,
          content: p.certifications.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.certifications.map((cert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${cert.certificationName} - ${cert.issuingOrganization}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add certifications', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-certifications'),
        ),

        // Licenses Card
        _buildInfoCard(
          title: 'Licenses',
          icon: Icons.badge,
          iconColor: Colors.purple,
          content: p.licenses.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.licenses.map((lic) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.badge, size: 16, color: Colors.purple),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${lic.licenseName} - ${lic.issuingAuthority}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : const Text('Add licenses', style: TextStyle(color: AppColors.neutral600)),
          onTap: () => Navigator.pushNamed(context, '/add-licenses'),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required VoidCallback onTap,
  }) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      content,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationsTab() {
    return Consumer<VerificationProvider>(
      builder: (context, vp, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Verifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
          const SizedBox(height: 8),
          const Text('Profiles with verifications are more likely to be selected',
              style: TextStyle(fontSize: 14, color: AppColors.neutral600)),
          const SizedBox(height: 20),

          _buildVerificationCard(
            title: 'Valid Philippine ID',
            subtitle: 'Government-issued ID with selfie',
            icon: Icons.badge,
            type: 'government_id',
            status: vp.statusFor('government_id'),
          ),
          _buildVerificationCard(
            title: 'Phone Number',
            subtitle: 'Verify via SMS code',
            icon: Icons.phone,
            type: 'phone',
            status: vp.statusFor('phone'),
          ),
          _buildVerificationCard(
            title: 'Email',
            subtitle: 'Verify via email link',
            icon: Icons.email,
            type: 'email',
            status: vp.statusFor('email'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    required String status,
  }) {
    final isVerified = status == 'verified';
    final isPending  = status == 'pending';
    final isRejected = status == 'rejected';
    final hasSubmitted = isPending || isVerified || isRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () async {
            // If already verified, don't allow navigation
            if (isVerified) return;
            
            // If pending or rejected, show retake confirmation dialog
            if (hasSubmitted) {
              final shouldRetake = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Retake Verification?'),
                  content: Text(
                    isRejected 
                      ? 'Your previous submission was rejected. Would you like to submit new documents?'
                      : 'You have already submitted verification documents. Would you like to retake and resubmit?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Retake'),
                    ),
                  ],
                ),
              );
              
              if (shouldRetake != true) return;
            }
            
            // Navigate to verification screen
            await Navigator.pushNamed(context, '/verification',
                arguments: {'type': type, 'title': title, 'subtitle': subtitle});
            if (mounted) context.read<VerificationProvider>().fetchVerifications();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.success.withValues(alpha: 0.1)
                        : isPending
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : isRejected
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.check_circle : isPending ? Icons.hourglass_top : isRejected ? Icons.error_outline : icon,
                    color: isVerified ? AppColors.success : isPending ? AppColors.warning : isRejected ? AppColors.error : AppColors.neutral600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                      Text(
                        isVerified ? 'Verified' : isPending ? 'Under review' : isRejected ? 'Rejected - Tap to retake' : subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified ? AppColors.success : isPending ? AppColors.warning : isRejected ? AppColors.error : AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning)),
                  )
                else if (isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Retake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}

