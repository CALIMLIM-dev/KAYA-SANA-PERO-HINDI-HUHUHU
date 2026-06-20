import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: const Center(
        child: Text('Conversations Screen - Coming Soon'),
      ),
    );
  }
}
