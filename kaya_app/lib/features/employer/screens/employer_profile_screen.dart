import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class EmployerProfileScreen extends StatelessWidget {
  const EmployerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employer Profile'),
      ),
      body: const Center(
        child: Text('Employer Profile Screen - Coming Soon'),
      ),
    );
  }
}
