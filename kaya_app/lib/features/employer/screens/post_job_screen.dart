import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PostJobScreen extends StatelessWidget {
  const PostJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post a Job'),
      ),
      body: const Center(
        child: Text('Post Job Screen - Coming Soon'),
      ),
    );
  }
}
