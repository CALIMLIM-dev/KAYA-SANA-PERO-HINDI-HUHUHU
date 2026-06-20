import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Full screen photo selection - user picks how to add photo
/// NO BOTTOM SHEET, FULL SCREEN NAVIGATION
class AddPhotoScreen extends StatelessWidget {
  const AddPhotoScreen({super.key});

  void _takePhoto(BuildContext context) {
    // TODO: Implement camera when image_picker package is added
    // For now, return success
    Navigator.pop(context, true);
  }

  void _pickFromGallery(BuildContext context) {
    // TODO: Implement gallery picker when image_picker package is added
    // For now, return success
    Navigator.pop(context, true);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Instructions
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
                'A profile photo helps employers recognize you.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.neutral600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Take Photo Option
              _buildOptionCard(
                context: context,
                icon: Icons.camera_alt,
                iconColor: AppColors.primary,
                title: 'Take Photo',
                description: 'Use your camera to take a new photo',
                onTap: () => _takePhoto(context),
              ),
              
              const SizedBox(height: 16),
              
              // Choose from Gallery Option
              _buildOptionCard(
                context: context,
                icon: Icons.photo_library,
                iconColor: AppColors.accent,
                title: 'Choose from Gallery',
                description: 'Select an existing photo from your device',
                onTap: () => _pickFromGallery(context),
              ),
              
              const Spacer(),
              
              // Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use a clear, professional photo where your face is clearly visible.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.neutral700,
                          height: 1.5,
                        ),
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

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.neutral600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
