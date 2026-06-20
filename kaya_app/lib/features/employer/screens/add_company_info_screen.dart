import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Add Company Info - Name and contact person only
/// NO AUTO-FILL, fields start EMPTY
class AddCompanyInfoScreen extends StatefulWidget {
  final String employerType; // 'Company' or 'Individual'
  
  const AddCompanyInfoScreen({
    super.key,
    this.employerType = 'Company',
  });

  @override
  State<AddCompanyInfoScreen> createState() => _AddCompanyInfoScreenState();
}

class _AddCompanyInfoScreenState extends State<AddCompanyInfoScreen> {
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateSaveButton);
    _contactPersonController.addListener(_updateSaveButton);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  void _updateSaveButton() {
    setState(() {
      final nameValid = _nameController.text.trim().isNotEmpty;
      if (widget.employerType == 'Company') {
        _isSaveEnabled = nameValid && _contactPersonController.text.trim().isNotEmpty;
      } else {
        _isSaveEnabled = nameValid;
      }
    });
  }

  void _save() {
    final data = {
      'name': _nameController.text.trim(),
      'contactPerson': widget.employerType == 'Company' ? _contactPersonController.text.trim() : null,
    };
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final isCompany = widget.employerType == 'Company';
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isCompany ? 'Company Information' : 'Your Information',
          style: const TextStyle(
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
                  
                  Text(
                    isCompany ? 'What is your company name?' : 'What is your name?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: isCompany ? 'Company/Business Name' : 'Your Full Name',
                      hintText: isCompany ? 'e.g. ABC Construction Corp' : 'e.g. Juan Dela Cruz',
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
                    ),
                  ),
                  
                  if (isCompany) ...[
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Who should workers contact?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: _contactPersonController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Contact Person Name',
                        hintText: 'e.g. Maria Santos',
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
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
}
