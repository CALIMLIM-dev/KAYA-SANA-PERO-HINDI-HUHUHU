import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Add Employer About - Company/Individual description
/// NO AUTO-FILL, field starts EMPTY
class AddEmployerAboutScreen extends StatefulWidget {
  final String? initialValue;
  const AddEmployerAboutScreen({super.key, this.initialValue});

  @override
  State<AddEmployerAboutScreen> createState() => _AddEmployerAboutScreenState();
}

class _AddEmployerAboutScreenState extends State<AddEmployerAboutScreen> {
  late final TextEditingController _aboutController;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _aboutController = TextEditingController(text: widget.initialValue ?? '');
    _isSaveEnabled = (_aboutController.text.trim().length >= 20);
    _aboutController.addListener(_updateSaveButton);
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  void _updateSaveButton() {
    setState(() {
      _isSaveEnabled = _aboutController.text.trim().isNotEmpty &&
                       _aboutController.text.trim().length >= 20;
    });
  }

  void _save() {
    if (!_isSaveEnabled) return;
    Navigator.pop(context, _aboutController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _aboutController.text.length;
    
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
          'About',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Tell workers about your company',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'This helps workers understand what you do and why they should work with you',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral600,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // About Field
                  TextField(
                    controller: _aboutController,
                    autofocus: true,
                    maxLines: 8,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'About Your Company',
                      hintText: 'Describe what your company does, your values, and what makes you a great employer...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.neutral300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      helperText: 'Minimum 20 characters',
                      helperStyle: TextStyle(
                        color: charCount >= 20 ? AppColors.success : AppColors.neutral600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tips for a great description',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTip('• What does your company do?'),
                        _buildTip('• What makes you a great employer?'),
                        _buildTip('• What values are important to you?'),
                        _buildTip('• What kind of projects do you work on?'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Save Button
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
                  onPressed: _isSaveEnabled ? _save : null,
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
                    'Save',
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

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.neutral900,
          height: 1.5,
        ),
      ),
    );
  }
}
