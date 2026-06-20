import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Full screen certifications management - photo OR PDF upload
/// NO AUTO-FILL, NO HARDCODED DATA, ALL FIELDS START EMPTY
class AddCertificationsScreen extends StatefulWidget {
  const AddCertificationsScreen({super.key});

  @override
  State<AddCertificationsScreen> createState() => _AddCertificationsScreenState();
}

class _AddCertificationsScreenState extends State<AddCertificationsScreen> {
  final List<Map<String, dynamic>> _certifications = [];
  bool _isSaveEnabled = false;

  void _updateSaveButton() {
    setState(() {
      _isSaveEnabled = _certifications.isNotEmpty;
    });
  }

  Future<void> _addOrEditCertification([Map<String, dynamic>? existingCert, int? index]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddCertificationFormScreen(existingCertification: existingCert),
      ),
    );
    
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (index != null) {
          // Edit existing
          _certifications[index] = result;
        } else {
          // Add new
          _certifications.add(result);
        }
        _updateSaveButton();
      });
    }
  }

  void _deleteCertification(int index) {
    setState(() {
      _certifications.removeAt(index);
      _updateSaveButton();
    });
  }

  void _saveCertifications() {
    if (_certifications.isNotEmpty) {
      Navigator.pop(context, _certifications);
    }
  }

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
          'Certifications & Licenses',
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
                  
                  // Instructions
                  const Text(
                    'Add your certifications',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Upload certificate documents (photo or PDF).',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral600,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add Certification Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addOrEditCertification(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Certification'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // List of Added Certifications
                  if (_certifications.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 48,
                              color: AppColors.neutral400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No certifications added yet',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.neutral600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Certification/License" to get started',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.neutral500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _certifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cert = _certifications[index];
                        return _buildCertificationCard(cert, index);
                      },
                    ),
                ],
              ),
            ),
          ),
          
          // Save Button (Bottom)
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
                  onPressed: _isSaveEnabled ? _saveCertifications : null,
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

  Widget _buildCertificationCard(Map<String, dynamic> cert, int index) {
    final bool hasPhoto = cert['hasPhoto'] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo indicator
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: hasPhoto 
                      ? AppColors.success.withValues(alpha: 0.1) 
                      : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasPhoto ? Icons.check_circle : Icons.image_outlined,
                  color: hasPhoto ? AppColors.success : AppColors.neutral400,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cert['issuer'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                onPressed: () => _addOrEditCertification(cert, index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                onPressed: () => _deleteCertification(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Issued: ${cert['year'] ?? ''}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutral600,
            ),
          ),
          if (!hasPhoto) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Photo not uploaded',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Form screen for adding/editing a single certification
class _AddCertificationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingCertification;
  
  const _AddCertificationFormScreen({this.existingCertification});

  @override
  State<_AddCertificationFormScreen> createState() => _AddCertificationFormScreenState();
}

class _AddCertificationFormScreenState extends State<_AddCertificationFormScreen> {
  final _titleController = TextEditingController();
  final _issuerController = TextEditingController();
  final _yearController = TextEditingController();
  bool _hasPhoto = false;
  bool _isGenuineConfirmed = false;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill if editing
    if (widget.existingCertification != null) {
      _titleController.text = widget.existingCertification!['title'] ?? '';
      _issuerController.text = widget.existingCertification!['issuer'] ?? '';
      _yearController.text = widget.existingCertification!['year'] ?? '';
      _hasPhoto = widget.existingCertification!['hasPhoto'] ?? false;
    }
    
    _titleController.addListener(_updateSaveButton);
    _issuerController.addListener(_updateSaveButton);
    _yearController.addListener(_updateSaveButton);
    _updateSaveButton();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _issuerController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateSaveButton() {
    setState(() {
      _isSaveEnabled = _titleController.text.trim().isNotEmpty &&
                       _issuerController.text.trim().isNotEmpty &&
                       _yearController.text.trim().isNotEmpty &&
                       _hasPhoto &&
                       _isGenuineConfirmed;
    });
  }

  Future<void> _selectYear() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Year Issued',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.neutral900,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _yearController.text = '${picked.year}';
        _updateSaveButton();
      });
    }
  }

  void _uploadPhoto() {
    // TODO: Implement actual photo picker when image_picker is added
    // For now, simulate photo upload
    setState(() {
      _hasPhoto = true;
      _updateSaveButton();
    });
  }

  void _saveCertification() {
    final title = _titleController.text.trim();
    final issuer = _issuerController.text.trim();
    final year = _yearController.text.trim();
    
    if (title.isNotEmpty && issuer.isNotEmpty && year.isNotEmpty) {
      Navigator.pop(context, {
        'title': title,
        'issuer': issuer,
        'year': year,
        'hasPhoto': _hasPhoto,
      });
    }
  }

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
        title: Text(
          widget.existingCertification != null ? 'Edit Certification' : 'Add Certification',
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
                  // Title Field
                  TextField(
                    controller: _titleController,
                    autofocus: widget.existingCertification == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Certification Name',
                      hintText: 'e.g. Safety Training Certificate',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Issuer Field
                  TextField(
                    controller: _issuerController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Issued By',
                      hintText: 'e.g. TESDA, Red Cross',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Year Field
                  TextField(
                    controller: _yearController,
                    readOnly: true,
                    onTap: _selectYear,
                    decoration: InputDecoration(
                      labelText: 'Year Issued',
                      hintText: 'YYYY',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: const Icon(Icons.calendar_today, size: 20),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Photo Upload Section with Confirmation
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neutral200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Upload Certificate Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_hasPhoto)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _uploadPhoto,
                              icon: const Icon(Icons.upload, size: 20),
                              label: const Text('Choose Photo or PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.neutral300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Document uploaded',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _uploadPhoto,
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // Divider
                        Container(
                          height: 1,
                          color: AppColors.neutral200,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Confirmation Checkbox - Inside the same container
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _isGenuineConfirmed,
                              onChanged: (value) {
                                setState(() {
                                  _isGenuineConfirmed = value ?? false;
                                  _updateSaveButton();
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12, left: 4),
                                child: Text(
                                  'I confirm this document is genuine. Submitting fake documents will result in permanent ban and may be reported to authorities.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.neutral700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Save Button (Bottom)
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
                  onPressed: _isSaveEnabled ? _saveCertification : null,
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
