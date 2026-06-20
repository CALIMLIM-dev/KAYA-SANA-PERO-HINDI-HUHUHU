import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LeaveReviewScreen extends StatelessWidget {
  const LeaveReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leave Review'),
      ),
      body: const Center(
        child: Text('Leave Review Screen - Coming Soon'),
      ),
    );
  }
}
