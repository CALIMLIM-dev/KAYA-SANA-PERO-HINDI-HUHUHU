import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MyInvitationsScreen extends StatelessWidget {
  const MyInvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Invitations'),
      ),
      body: const Center(
        child: Text('My Invitations Screen - Coming Soon'),
      ),
    );
  }
}
