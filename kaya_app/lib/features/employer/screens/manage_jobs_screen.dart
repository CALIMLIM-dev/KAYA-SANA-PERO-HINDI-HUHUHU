import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ManageJobsScreen extends StatelessWidget {
  const ManageJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Jobs'),
      ),
      body: const Center(
        child: Text('Manage Jobs Screen - Coming Soon'),
      ),
    );
  }
}
