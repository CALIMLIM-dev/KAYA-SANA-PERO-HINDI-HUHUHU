import 'package:flutter/material.dart';

/// Edit Worker Profile — redirects to the profile management screen
/// where workers fill in their details (my_worker_profile_screen)
class EditWorkerProfileScreen extends StatelessWidget {
  const EditWorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Immediately navigate to the real profile screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/my-worker-profile');
    });
    return const SizedBox.shrink();
  }
}
