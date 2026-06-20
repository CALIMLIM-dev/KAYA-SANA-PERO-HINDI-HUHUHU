import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class EditEmployerProfileScreen extends StatelessWidget {
  const EditEmployerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: const Center(
        child: Text('Edit Employer Profile Screen - Coming Soon'),
      ),
    );
  }
}
