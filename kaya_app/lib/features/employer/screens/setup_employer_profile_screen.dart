import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Employer Profile Setup - Step 1: Choose Company or Individual
/// Clean toggle design, NO AUTO-FILL, user must choose their type
class SetupEmployerProfileScreen extends StatefulWidget {
  const SetupEmployerProfileScreen({super.key});

  @override
  State<SetupEmployerProfileScreen> createState() => _SetupEmployerProfileScreenState();
}

class _SetupEmployerProfileScreenState extends State<SetupEmployerProfileScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Set Up Employer Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
                  const Text(
                    'I am a...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Select your employer type to continue',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral600,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Toggle Container
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildToggleOption(
                            type: 'Company',
                            icon: Icons.business_center,
                            label: 'Company',
                            isSelected: _selectedType == 'Company',
                            onTap: () {
                              setState(() {
                                _selectedType = 'Company';
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildToggleOption(
                            type: 'Individual',
                            icon: Icons.person,
                            label: 'Individual',
                            isSelected: _selectedType == 'Individual',
                            onTap: () {
                              setState(() {
                                _selectedType = 'Individual';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Description based on selection
                  if (_selectedType != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _selectedType == 'Company' ? Icons.business_center : Icons.person,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedType == 'Company' ? 'Company / Business' : 'Individual / Homeowner',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neutral900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedType == 'Company'
                                ? 'Perfect for businesses and organizations looking to hire skilled workers for projects and ongoing work. You\'ll be able to post multiple jobs and manage a team.'
                                : 'Ideal for homeowners and individuals hiring workers for personal projects like home repairs, renovations, or one-time tasks.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.neutral600,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Continue Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedType != null
                      ? () {
                          Navigator.pushNamed(
                            context,
                            '/add-employer-details',
                            arguments: _selectedType,
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    disabledForegroundColor: AppColors.neutral600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String type,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.neutral600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
