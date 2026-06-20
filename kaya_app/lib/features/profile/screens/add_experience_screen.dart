import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Full screen experience management - user can add multiple experiences
/// NO AUTO-FILL, NO HARDCODED DATA, ALL FIELDS START EMPTY
class AddExperienceScreen extends StatefulWidget {
  const AddExperienceScreen({super.key});

  @override
  State<AddExperienceScreen> createState() => _AddExperienceScreenState();
}

class _AddExperienceScreenState extends State<AddExperienceScreen> {
  final List<Map<String, String>> _experiences = [];
  bool _isSaveEnabled = false;

  void _updateSaveButton() {
    setState(() {
      _isSaveEnabled = _experiences.isNotEmpty;
    });
  }

  Future<void> _addOrEditExperience([Map<String, String>? existingExperience, int? index]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddExperienceFormScreen(existingExperience: existingExperience),
      ),
    );
    
    if (result != null && result is Map<String, String>) {
      setState(() {
        if (index != null) {
          // Edit existing
          _experiences[index] = result;
        } else {
          // Add new
          _experiences.add(result);
        }
        _updateSaveButton();
      });
    }
  }

  void _deleteExperience(int index) {
    setState(() {
      _experiences.removeAt(index);
      _updateSaveButton();
    });
  }

  void _saveExperiences() {
    if (_experiences.isNotEmpty) {
      Navigator.pop(context, _experiences);
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
          'Work Experience',
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
                    'Add your work experience',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Show employers your relevant work history.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral600,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add Experience Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addOrEditExperience(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Experience'),
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
                  
                  // List of Added Experiences
                  if (_experiences.isEmpty)
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
                              Icons.work_outline,
                              size: 48,
                              color: AppColors.neutral400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No experience added yet',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.neutral600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Experience" to get started',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _experiences.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final exp = _experiences[index];
                        return _buildExperienceCard(exp, index);
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
                  onPressed: _isSaveEnabled ? _saveExperiences : null,
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

  Widget _buildExperienceCard(Map<String, String> exp, int index) {
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
              Expanded(
                child: Text(
                  exp['jobTitle'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                onPressed: () => _addOrEditExperience(exp, index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                onPressed: () => _deleteExperience(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            exp['company'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${exp['startDate']} - ${exp['endDate']}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutral600,
            ),
          ),
          if (exp['description']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              exp['description'] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutral600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Form screen for adding/editing a single experience
class _AddExperienceFormScreen extends StatefulWidget {
  final Map<String, String>? existingExperience;
  
  const _AddExperienceFormScreen({this.existingExperience});

  @override
  State<_AddExperienceFormScreen> createState() => _AddExperienceFormScreenState();
}

class _AddExperienceFormScreenState extends State<_AddExperienceFormScreen> {
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill if editing
    if (widget.existingExperience != null) {
      _jobTitleController.text = widget.existingExperience!['jobTitle'] ?? '';
      _companyController.text = widget.existingExperience!['company'] ?? '';
      _startDateController.text = widget.existingExperience!['startDate'] ?? '';
      _endDateController.text = widget.existingExperience!['endDate'] ?? '';
      _descriptionController.text = widget.existingExperience!['description'] ?? '';
    }
    
    _jobTitleController.addListener(_updateSaveButton);
    _companyController.addListener(_updateSaveButton);
    _startDateController.addListener(_updateSaveButton);
    _endDateController.addListener(_updateSaveButton);
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateSaveButton() {
    setState(() {
      _isSaveEnabled = _jobTitleController.text.trim().isNotEmpty &&
                       _companyController.text.trim().isNotEmpty &&
                       _startDateController.text.trim().isNotEmpty &&
                       _endDateController.text.trim().isNotEmpty;
    });
  }

  Future<void> _selectDate(TextEditingController controller, String title) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      helpText: title,
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
        controller.text = '${picked.month}/${picked.year}';
        _updateSaveButton();
      });
    }
  }

  void _saveExperience() {
    final jobTitle = _jobTitleController.text.trim();
    final company = _companyController.text.trim();
    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (jobTitle.isNotEmpty && company.isNotEmpty && startDate.isNotEmpty && endDate.isNotEmpty) {
      Navigator.pop(context, {
        'jobTitle': jobTitle,
        'company': company,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
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
          widget.existingExperience != null ? 'Edit Experience' : 'Add Experience',
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
                  // Job Title Field
                  TextField(
                    controller: _jobTitleController,
                    autofocus: widget.existingExperience == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Job Title',
                      hintText: 'e.g. Plumber',
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
                  
                  // Company Field
                  TextField(
                    controller: _companyController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Company',
                      hintText: 'e.g. ABC Construction',
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
                  
                  // Start Date Field
                  TextField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () => _selectDate(_startDateController, 'Select Start Date'),
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      hintText: 'MM/YYYY',
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
                  
                  const SizedBox(height: 16),
                  
                  // End Date Field
                  TextField(
                    controller: _endDateController,
                    readOnly: true,
                    onTap: () => _selectDate(_endDateController, 'Select End Date'),
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      hintText: 'MM/YYYY or "Present"',
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
                  
                  const SizedBox(height: 16),
                  
                  // Description Field (Optional)
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Describe your responsibilities...',
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
                  onPressed: _isSaveEnabled ? _saveExperience : null,
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
