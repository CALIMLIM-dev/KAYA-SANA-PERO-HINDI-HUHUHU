import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Edit Job Screen — pre-filled form for editing an existing job post
/// Arguments: { title, category, description, budget, salaryType, location,
///              workersNeeded, isUrgent, isNegotiable, selectedSkills }
/// Only allowed if job status = 'open'
class EditJobScreen extends StatefulWidget {
  const EditJobScreen({super.key});

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController       = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController      = TextEditingController();
  final _locationController    = TextEditingController();
  final _workersNeededController = TextEditingController();

  String? _selectedCategory;
  String _salaryType = 'Daily';
  List<String> _selectedSkills = [];
  bool _isLoading = false;
  bool _isUrgent = false;
  bool _isNegotiable = false;
  bool _initialized = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Plumbing',        'icon': Icons.plumbing},
    {'name': 'Electrical',      'icon': Icons.electrical_services},
    {'name': 'Painting',        'icon': Icons.format_paint},
    {'name': 'Carpentry',       'icon': Icons.carpenter},
    {'name': 'Construction',    'icon': Icons.construction},
    {'name': 'HVAC',            'icon': Icons.ac_unit},
    {'name': 'Landscaping',     'icon': Icons.grass},
    {'name': 'Cleaning',        'icon': Icons.cleaning_services},
    {'name': 'Roofing',         'icon': Icons.roofing},
    {'name': 'Flooring',        'icon': Icons.layers},
    {'name': 'Automotive',      'icon': Icons.car_repair},
    {'name': 'Appliance Repair','icon': Icons.kitchen},
    {'name': 'Security',        'icon': Icons.security},
    {'name': 'Moving',          'icon': Icons.local_shipping},
    {'name': 'Pest Control',    'icon': Icons.bug_report},
    {'name': 'Pool Services',   'icon': Icons.pool},
    {'name': 'Delivery',        'icon': Icons.delivery_dining},
    {'name': 'Other',           'icon': Icons.build},
  ];

  final Map<String, List<String>> _categorySkills = {
    'Plumbing':        ['Plumbing', 'Pipe Repair', 'Emergency Service', 'Installation', 'Leak Detection'],
    'Electrical':      ['Wiring', 'Circuit Repair', 'Panel Installation', 'Troubleshooting', 'Lighting'],
    'Painting':        ['Interior Painting', 'Exterior Painting', 'Surface Preparation', 'Color Matching'],
    'Carpentry':       ['Cabinet Making', 'Furniture Repair', 'Framing', 'Trim Work', 'Custom Woodwork'],
    'Construction':    ['Concrete Work', 'Masonry', 'Tile Work', 'Drywall', 'Framing'],
    'HVAC':            ['AC Repair', 'Heating Installation', 'Duct Cleaning', 'Maintenance'],
    'Landscaping':     ['Lawn Care', 'Garden Design', 'Tree Trimming', 'Irrigation'],
    'Cleaning':        ['Deep Cleaning', 'Window Cleaning', 'Floor Polishing', 'Sanitization'],
    'Roofing':         ['Roof Repair', 'Installation', 'Inspection', 'Waterproofing'],
    'Flooring':        ['Tile Installation', 'Hardwood', 'Laminate', 'Vinyl'],
    'Automotive':      ['Engine Repair', 'Oil Change', 'Brake Service', 'Diagnostics'],
    'Appliance Repair':['Refrigerator', 'Washing Machine', 'Oven', 'Dishwasher'],
    'Security':        ['CCTV Installation', 'Alarm Systems', 'Access Control', 'Monitoring'],
    'Moving':          ['Packing', 'Loading', 'Transportation', 'Unpacking'],
    'Pest Control':    ['Termite Treatment', 'Rodent Control', 'Fumigation', 'Prevention'],
    'Pool Services':   ['Pool Cleaning', 'Chemical Balance', 'Repair', 'Maintenance'],
    'Delivery':        ['Same Day', 'Express', 'Bulk', 'Fragile Items'],
    'Other':           ['General Labor', 'Handyman', 'Specialized Work'],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    _workersNeededController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Pre-fill from route arguments
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      if (args != null) {
        _titleController.text       = args['title']         ?? '';
        _descriptionController.text = args['description']   ?? '';
        _budgetController.text      = args['budget']        ?? '';
        _locationController.text    = args['location']      ?? '';
        _workersNeededController.text =
            (args['workersNeeded'] ?? 1).toString();
        _selectedCategory = args['category'];
        _salaryType       = args['salaryType'] ?? 'Daily';
        _isUrgent         = args['isUrgent']   ?? false;
        _isNegotiable     = args['isNegotiable'] ?? false;
        _selectedSkills   = List<String>.from(args['selectedSkills'] ?? []);
      } else {
        // Default mock pre-fill for demo
        _titleController.text       = 'Emergency Pipe Repair';
        _descriptionController.text =
            'We need an experienced plumber to fix a burst pipe in our residential property.';
        _budgetController.text      = '1200';
        _locationController.text    = 'Pangasinan';
        _workersNeededController.text = '1';
        _selectedCategory = 'Plumbing';
        _salaryType       = 'Daily';
        _isUrgent         = true;
        _isNegotiable     = false;
        _selectedSkills   = ['Plumbing', 'Pipe Repair'];
      }
    }
  }

  List<String> get _availableSkills =>
      _selectedCategory != null ? (_categorySkills[_selectedCategory!] ?? []) : [];

  void _updateCategory(String? category) {
    setState(() {
      _selectedSkills = [];
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Edit Job',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
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

              // ── Basic Information ──
              _section(
                title: 'Basic Information',
                children: [
                  _label('Job Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDeco(
                        hint: 'e.g., Emergency Pipe Repair',
                        icon: Icons.work_outline),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Category'),
                  const SizedBox(height: 8),
                  _categorySelector(),
                  const SizedBox(height: 16),

                  _label('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _inputDeco(
                        hint: 'Describe the work in detail...',
                        icon: Icons.description),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                  ),

                  if (_selectedCategory != null &&
                      _availableSkills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _label('Required Skills'),
                    const SizedBox(height: 8),
                    _skillChips(),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // ── Workers Needed ──
              _section(
                title: 'Workers Needed',
                children: [
                  TextFormField(
                    controller: _workersNeededController,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDeco(hint: 'e.g., 1', icon: Icons.people),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      final n = int.tryParse(v!);
                      if (n == null || n < 1) return 'Must be at least 1';
                      if (n > 9) return 'Maximum 9 workers';
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Salary & Location ──
              _section(
                title: 'Salary & Location',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Salary'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco(
                                  hint: '1,200', prefix: '₱ '),
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Payment'),
                            const SizedBox(height: 8),
                            _dropdown(
                              value: _salaryType,
                              items: ['Daily', 'Hourly', 'Project'],
                              onChanged: (v) =>
                                  setState(() => _salaryType = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Location'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: _inputDeco(
                        hint: 'e.g., Pangasinan',
                        icon: Icons.location_on),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Job Priority ──
              _section(
                title: 'Job Priority (Optional)',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _toggleButton(
                          label: 'Urgent',
                          icon: Icons.flash_on,
                          isActive: _isUrgent,
                          onTap: () =>
                              setState(() => _isUrgent = !_isUrgent),
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _toggleButton(
                          label: 'Negotiable',
                          icon: Icons.handshake,
                          isActive: _isNegotiable,
                          onTap: () => setState(
                              () => _isNegotiable = !_isNegotiable),
                          color: AppColors.success,
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

  // ─── widgets ─────────────────────────────────────────────────────────────────

  Widget _section(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: AppColors.neutral200, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral900)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral900));

  InputDecoration _inputDeco(
      {required String hint, IconData? icon, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.neutral400, fontSize: 15),
      prefixText: prefix,
      prefixStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral900),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.neutral500, size: 20)
          : null,
      filled: true,
      fillColor: AppColors.neutral50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.neutral300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.neutral300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error)),
    );
  }

  Widget _dropdown(
      {required String value,
      required List<String> items,
      required ValueChanged<String?> onChanged}) {
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
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.neutral600),
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.neutral900))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _categorySelector() {
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedCategory != null
                ? AppColors.primary
                : AppColors.neutral300,
            width: _selectedCategory != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_selectedCategory != null)
              Icon(
                _categories.firstWhere(
                    (c) => c['name'] == _selectedCategory)['icon'],
                color: AppColors.primary,
                size: 20,
              )
            else
              const Icon(Icons.category,
                  color: AppColors.neutral400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCategory ?? 'Select category',
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedCategory != null
                      ? AppColors.neutral900
                      : AppColors.neutral400,
                  fontWeight: _selectedCategory != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                color: AppColors.neutral600),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Category',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSel = _selectedCategory == cat['name'];
                  return ListTile(
                    leading: Icon(cat['icon'],
                        color: isSel
                            ? AppColors.primary
                            : AppColors.neutral600),
                    title: Text(cat['name'],
                        style: TextStyle(
                          fontWeight: isSel
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSel
                              ? AppColors.primary
                              : AppColors.neutral900,
                        )),
                    trailing: isSel
                        ? const Icon(Icons.check,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      _updateCategory(cat['name']);
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

  Widget _skillChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSkills.map((skill) {
        final isSel = _selectedSkills.contains(skill);
        return GestureDetector(
          onTap: () => setState(() {
            isSel
                ? _selectedSkills.remove(skill)
                : _selectedSkills.add(skill);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel
                    ? AppColors.primary
                    : AppColors.neutral300,
              ),
            ),
            child: Text(skill,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSel
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: isSel
                      ? Colors.white
                      : AppColors.neutral700,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon,
                color: isActive ? Colors.white : AppColors.neutral600,
                size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isActive ? Colors.white : AppColors.neutral600)),
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
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.neutral300,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isLoading = true);
    // TODO: Call JobProvider.updateJob(...)
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}
