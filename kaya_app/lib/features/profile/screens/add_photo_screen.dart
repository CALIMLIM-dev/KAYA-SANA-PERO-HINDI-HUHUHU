import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../core/widgets/app_toast.dart';

class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({super.key});

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  bool _isLoading = false;

  Future<void> _pick({required bool fromCamera}) async {
    setState(() => _isLoading = true);
    final provider = context.read<WorkerProfileProvider>();
    final success = await provider.uploadPhoto(fromCamera: fromCamera);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      AppToast.success(context, 'Photo uploaded successfully');
      Navigator.pop(context, true);
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Failed to upload photo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Photo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    const Text(
                      'Choose how to add your photo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'A clear profile photo helps employers recognize you.',
                      style: TextStyle(fontSize: 15, color: AppColors.neutral600, height: 1.5),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    _buildOption(
                      icon: Icons.camera_alt,
                      iconColor: AppColors.primary,
                      title: 'Take Photo',
                      description: 'Use your camera to take a new photo',
                      onTap: () => _pick(fromCamera: true),
                    ),

                    const SizedBox(height: 16),

                    _buildOption(
                      icon: Icons.photo_library,
                      iconColor: AppColors.accent,
                      title: 'Choose from Gallery',
                      description: 'Select an existing photo from your device',
                      onTap: () => _pick(fromCamera: false),
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Use a clear, professional photo where your face is fully visible.',
                              style: TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral900)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}
