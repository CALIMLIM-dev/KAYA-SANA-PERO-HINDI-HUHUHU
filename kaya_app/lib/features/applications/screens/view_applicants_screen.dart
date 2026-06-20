import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ViewApplicantsScreen extends StatelessWidget {
  const ViewApplicantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Applicants'),
      ),
      body: const Center(
        child: Text('View Applicants Screen - Coming Soon'),
      ),
    );
  }
}
