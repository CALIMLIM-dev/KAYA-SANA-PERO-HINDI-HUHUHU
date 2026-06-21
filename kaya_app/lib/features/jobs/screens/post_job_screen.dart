import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';

/// Post Job Screen - Clean, professional design following industry best practices
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();
  final _workersNeededController = TextEditingController(text: '1');
  
  String? _selectedCategory;
  String? _customCategoryName; // used when 'Other' is selected
  String _salaryType = 'Daily';
  final List<String> _selectedSkills = [];
  final _customSkillController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isUrgent = false;
  bool _isNegotiable = false;

  // Categories
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Plumbing', 'icon': Icons.plumbing},
    {'name': 'Electrical', 'icon': Icons.electrical_services},
    {'name': 'Painting', 'icon': Icons.format_paint},
    {'name': 'Carpentry', 'icon': Icons.carpenter},
    {'name': 'Construction', 'icon': Icons.construction},
    {'name': 'HVAC', 'icon': Icons.ac_unit},
    {'name': 'Landscaping', 'icon': Icons.grass},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services},
    {'name': 'Roofing', 'icon': Icons.roofing},
    {'name': 'Flooring', 'icon': Icons.layers},
    {'name': 'Automotive', 'icon': Icons.car_repair},
    {'name': 'Appliance Repair', 'icon': Icons.kitchen},
    {'name': 'Security', 'icon': Icons.security},
    {'name': 'Moving', 'icon': Icons.local_shipping},
    {'name': 'Pest Control', 'icon': Icons.bug_report},
    {'name': 'Pool Services', 'icon': Icons.pool},
    {'name': 'Delivery', 'icon': Icons.delivery_dining},
    {'name': 'Other', 'icon': Icons.build},
  ];

  // Skills for each category
  final Map<String, List<String>> _categorySkills = {
    'Plumbing': ['Plumbing', 'Pipe Repair', 'Emergency Service', 'Installation', 'Leak Detection'],
    'Electrical': ['Wiring', 'Circuit Repair', 'Panel Installation', 'Troubleshooting', 'Lighting'],
    'Painting': ['Interior Painting', 'Exterior Painting', 'Surface Preparation', 'Color Matching'],
    'Carpentry': ['Cabinet Making', 'Furniture Repair', 'Framing', 'Trim Work', 'Custom Woodwork'],
    'Construction': ['Concrete Work', 'Masonry', 'Tile Work', 'Drywall', 'Framing'],
    'HVAC': ['AC Repair', 'Heating Installation', 'Duct Cleaning', 'Maintenance'],
    'Landscaping': ['Lawn Care', 'Garden Design', 'Tree Trimming', 'Irrigation'],
    'Cleaning': ['Deep Cleaning', 'Window Cleaning', 'Floor Polishing', 'Sanitization'],
    'Roofing': ['Roof Repair', 'Installation', 'Inspection', 'Waterproofing'],
    'Flooring': ['Tile Installation', 'Hardwood', 'Laminate', 'Vinyl'],
    'Automotive': ['Engine Repair', 'Oil Change', 'Brake Service', 'Diagnostics'],
    'Appliance Repair': ['Refrigerator', 'Washing Machine', 'Oven', 'Dishwasher'],
    'Security': ['CCTV Installation', 'Alarm Systems', 'Access Control', 'Monitoring'],
    'Moving': ['Packing', 'Loading', 'Transportation', 'Unpacking'],
    'Pest Control': ['Termite Treatment', 'Rodent Control', 'Fumigation', 'Prevention'],
    'Pool Services': ['Pool Cleaning', 'Chemical Balance', 'Repair', 'Maintenance'],
    'Delivery': ['Same Day', 'Express', 'Bulk', 'Fragile Items'],
    'Other': ['General Labor', 'Handyman', 'Specialized Work'],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    _workersNeededController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  List<String> get _availableSkills {
    if (_selectedCategory == null) return [];
    return _categorySkills[_selectedCategory!] ?? [];
  }

  void _updateSkillsForCategory(String? category) {
    setState(() {
      _selectedSkills.clear();
      _selectedCategory = category;
      if (category != 'Other') _customCategoryName = null;
    });
  }

  void _handleUrgentToggle() {
    if (!_isUrgent) {
      // Show popup when enabling urgent
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flash_on, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Mark as Urgent?'),
            ],
          ),
          content: const Text(
            'Urgent jobs get priority placement and appear at the top of search results, helping you find workers faster.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isUrgent = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: const Text('Mark as Urgent'),
            ),
          ],
        ),
      );
    } else {
      // Just toggle off without popup
      setState(() => _isUrgent = false);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
        if (_selectedImages.length > 4) {
          _selectedImages.removeRange(4, _selectedImages.length);
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text(
          'Post a Job',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 12),
              
              // Basic Information
              _buildSection(
                title: 'Basic Information',
                children: [
                  _buildLabel('Job Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      hint: 'e.g., Emergency Pipe Repair',
                      icon: Icons.work_outline,
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel('Category'),
                  const SizedBox(height: 8),
                  _buildCategorySelector(),

                  // Custom category name — only when "Other" selected
                  if (_selectedCategory == 'Other') ...[
                    const SizedBox(height: 12),
                    _buildLabel('Specify Category'),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _customCategoryName,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (v) => setState(() => _customCategoryName = v.trim()),
                      decoration: _inputDecoration(
                        hint: 'e.g., Welding, Tailoring, Massage Therapy',
                        icon: Icons.edit_outlined,
                      ),
                      validator: (v) =>
                          _selectedCategory == 'Other' && (v?.isEmpty ?? true)
                              ? 'Please specify the category'
                              : null,
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  _buildLabel('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _inputDecoration(
                      hint: 'Describe the work in detail...',
                      icon: Icons.description,
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  
                  if (_selectedCategory != null && _availableSkills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLabel('Required Skills'),
                    const SizedBox(height: 8),
                    _buildSkillChips(),
                    const SizedBox(height: 10),
                    _buildCustomSkillInput(),
                  ],

                  // For "Other" category with no predefined skills, show custom skill input
                  if (_selectedCategory == 'Other' && _availableSkills.isEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLabel('Required Skills'),
                    const SizedBox(height: 8),
                    _buildCustomSkillInput(),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Job Photos
              _buildSection(
                title: 'Job Photos (Optional)',
                subtitle: 'Add up to 4 photos',
                children: [
                  _buildPhotoSelector(),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Workers Needed
              _buildSection(
                title: 'Workers Needed',
                children: [
                  TextFormField(
                    controller: _workersNeededController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      hint: 'e.g., 1',
                      icon: Icons.people,
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final number = int.tryParse(value!);
                      if (number == null || number < 1) return 'Must be at least 1';
                      if (number > 9) return 'Maximum 9 workers';
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Salary & Location
              _buildSection(
                title: 'Salary & Location',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Salary'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                hint: '1,200',
                                prefix: '₱ ',
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Payment'),
                            const SizedBox(height: 8),
                            _buildDropdown(
                              value: _salaryType,
                              items: ['Daily', 'Hourly', 'Project'],
                              onChanged: (value) => setState(() => _salaryType = value!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel('Location'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: _inputDecoration(
                      hint: 'e.g., Pangasinan',
                      icon: Icons.location_on,
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Job Priority
              _buildSection(
                title: 'Job Priority (Optional)',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton(
                          label: 'Urgent',
                          icon: Icons.flash_on,
                          isActive: _isUrgent,
                          onTap: _handleUrgentToggle,
                          color: AppColors.accent,
                          showWarning: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToggleButton(
                          label: 'Negotiable',
                          icon: Icons.handshake,
                          isActive: _isNegotiable,
                          onTap: () => setState(() => _isNegotiable = !_isNegotiable),
                          color: AppColors.success,
                          showWarning: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutral600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.neutral900,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.neutral400,
        fontSize: 15,
      ),
      prefixText: prefix,
      prefixStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.neutral900,
      ),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.neutral500, size: 20) : null,
      filled: true,
      fillColor: AppColors.neutral50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neutral300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neutral300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.neutral600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.neutral900,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedCategory != null ? AppColors.primary : AppColors.neutral300,
            width: _selectedCategory != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_selectedCategory != null)
              Icon(
                _categories.firstWhere((c) => c['name'] == _selectedCategory)['icon'],
                color: AppColors.primary,
                size: 20,
              )
            else
              Icon(Icons.category, color: AppColors.neutral400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCategory ?? 'Select category',
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedCategory != null ? AppColors.neutral900 : AppColors.neutral400,
                  fontWeight: _selectedCategory != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.neutral600),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category['name'];
                  return ListTile(
                    leading: Icon(
                      category['icon'],
                      color: isSelected ? AppColors.primary : AppColors.neutral600,
                    ),
                    title: Text(
                      category['name'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.neutral900,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      _updateSkillsForCategory(category['name']);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSkills.map((skill) {
        final isSelected = _selectedSkills.contains(skill);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedSkills.remove(skill);
              } else {
                _selectedSkills.add(skill);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.neutral300,
              ),
            ),
            child: Text(
              skill,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.neutral700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSkillInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Already added custom skills
        if (_selectedSkills.where((s) => !_availableSkills.contains(s)).isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedSkills
                .where((s) => !_availableSkills.contains(s))
                .map((skill) => Chip(
                      label: Text(skill, style: const TextStyle(fontSize: 13)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      deleteIconColor: AppColors.primary,
                      onDeleted: () => setState(() => _selectedSkills.remove(skill)),
                    ))
                .toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSkillController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: 'Add a custom skill...',
                  icon: Icons.add_circle_outline,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                final skill = _customSkillController.text.trim();
                if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
                  setState(() {
                    _selectedSkills.add(skill);
                    _customSkillController.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoSelector() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          // Existing photos
          ...List.generate(_selectedImages.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _selectedImages[index],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // Add photo button
          if (_selectedImages.length < 4)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.neutral300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: AppColors.neutral500, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    required bool showWarning,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: showWarning
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    '⚠️ Warning: Your account might get flagged for misleading information if job is not actually urgent',
                    style: TextStyle(fontSize: 13),
                  ),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : AppColors.neutral300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.neutral600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.neutral600,
              ),
            ),
            if (showWarning) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.error_outline,
                color: isActive ? Colors.white : AppColors.warning,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.neutral200),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.neutral300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post Job',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitJob() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      setState(() => _isLoading = true);
      
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }
}
