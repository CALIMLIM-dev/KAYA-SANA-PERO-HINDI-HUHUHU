import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Applications'),
      ),
      body: const Center(
        child: Text('My Applications Screen - Coming Soon'),
      ),
    );
  }
}
