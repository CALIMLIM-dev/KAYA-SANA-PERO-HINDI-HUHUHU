import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ApplicantReviewScreen extends StatelessWidget {
  const ApplicantReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Applicant'),
      ),
      body: const Center(
        child: Text('Applicant Review Screen - Coming Soon'),
      ),
    );
  }
}
