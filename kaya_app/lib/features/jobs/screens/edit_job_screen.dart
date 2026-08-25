import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/skill_model.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/widgets/app_toast.dart';

/// Edit Job Screen — pre-filled form for editing an existing job post
/// Arguments: { id, title, category, category_id, description, budget,
///              salaryType, location, workersNeeded, isUrgent, isNegotiable,
///              selectedSkills }
/// `id` is required — without it the job cannot be updated.
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

  /// Id of the job being edited, from route arguments.
  int? _jobId;
  int? _categoryId;

  /// Structured location chosen from the picker.
  LocationModel? _selectedLocation;

  String? _selectedCategory;
  String _salaryType = 'Daily';

  /// Real skill ids, so the job's requirements can be matched against the
  /// skills workers picked during onboarding. The old `List<String>` of names
  /// came from a hardcoded map and could never be sent — the server takes ids.
  List<int> _selectedSkillIds = [];

  final _budgetMaxController = TextEditingController();
  bool _isLoading = false;
  // Prefilled from the job being edited — see the note in didChangeDependencies.
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isUrgent = false;
  bool _isNegotiable = false;
  bool _initialized = false;

  /// Categories from the server, each carrying its real id.
  ///
  /// The hardcoded list below has no ids at all, which is why picking a new
  /// category could never change the job's category — and it carried an
  /// "Other" entry that does not exist in the categories table.
  List<Map<String, dynamic>> get _categories {
    final rows = context.read<WorkerProfileProvider>().categories;
    if (rows.isEmpty) return _fallbackCategories;

    /*
        The type argument is load-bearing, not decoration.

        Without it Dart infers the literal's value type as the least upper
        bound of int, String and IconData - which is Object - so this returned
        a List<Map<String, Object>> at runtime while the signature promised
        List<Map<String, dynamic>>. Map is covariant, so that compiles. It then
        blew up on the first firstWhere below, because the compiler typed
        orElse from the declared type and the real list demanded the other:

          type '() => Map<String, dynamic>' is not a subtype of
          type '(() => Map<String, Object>)?' of 'orElse'

        Editing any job whose category had loaded from the API crashed on that
        line. The fallback list is declared List<Map<String, dynamic>>, so its
        literals infer correctly and that path never failed - which is what
        made it look intermittent.
    */
    return rows
        .map<Map<String, dynamic>>((c) => {
              'id': c.id,
              'name': c.name,
              'icon': _iconFor(c.name),
            })
        .toList();
  }

  /// Icons are client-side because the table has no icon column. An unmapped
  /// name gets a generic tool rather than a blank space.
  static IconData _iconFor(String name) {
    for (final c in _fallbackCategories) {
      if ((c['name'] as String).toLowerCase() == name.toLowerCase()) {
        return c['icon'] as IconData;
      }
    }
    return Icons.build;
  }

  /// Only used to look up icons, and as a last resort if the taxonomy has not
  /// loaded yet. Never used to derive an id.
  static final List<Map<String, dynamic>> _fallbackCategories = [
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


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    _workersNeededController.dispose();
    _budgetMaxController.dispose();
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
      // NOTE: the mock "demo" pre-fill that used to live in the else branch is
      // gone. It silently populated a real edit form with placeholder text, so
      // saving would have overwritten a genuine job post with fake data.
      if (args != null) {
        _jobId = args['id'] as int? ?? args['jobId'] as int?;
        _titleController.text       = (args['title'] ?? '').toString();
        _descriptionController.text = (args['description'] ?? '').toString();
        _budgetController.text      =
            (args['budget'] ?? args['budget_min'] ?? '').toString();
        _locationController.text    = (args['location'] ?? '').toString();
        _workersNeededController.text =
            (args['workersNeeded'] ?? 1).toString();
        _selectedCategory = args['category'] as String?;
        _categoryId       = args['category_id'] as int?;
        _budgetMaxController.text =
            (args['budget_max'] ?? '').toString().replaceAll('null', '');

        /*
            Read the job's own values, not this form's defaults.

            These four used to fall back to Daily / not urgent / not
            negotiable because the caller never sent them. The form showed an
            urgent job as ordinary — and now that the payload includes them,
            defaulting would write that back and un-urgent the job on save.
        */
        _salaryType = _periodToLabel(args['budget_period'] as String?);
        _isUrgent     = args['is_urgent'] == true || args['isUrgent'] == true;
        _isNegotiable = args['is_negotiable'] == true || args['isNegotiable'] == true;
        _selectedSkillIds = List<int>.from(args['skill_ids'] ?? const <int>[]);

        /*
            Same trap as the four above, and worse.

            The payload below sends start_date, and update() accepts it as
            nullable — so failing to prefill here would send null and erase the
            job's schedule the first time the employer corrects a typo. Read the
            job's own dates or send nothing at all.
        */
        _startDate = DateTime.tryParse((args['start_date'] ?? '').toString());
        _endDate   = DateTime.tryParse((args['end_date'] ?? '').toString());
      }

      // The category picker and skill chips read the server's taxonomy, so it
      // has to be there. Without this the picker falls back to the local list
      // (icons only, no ids) and no skill chip can appear.
      final taxonomy = context.read<WorkerProfileProvider>();
      if (taxonomy.categories.isEmpty) taxonomy.fetchCategories();
      if (taxonomy.availableSkills.isEmpty) taxonomy.fetchSkills();
    }
  }

  // ── Schedule ────────────────────────────────────────────────────────────────

  Widget _dateRow({
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final shown = value == null
        ? null
        : '${months[value.month - 1]} ${value.day}, ${value.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.neutral100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: shown != null ? AppColors.primary : AppColors.neutral300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 18,
                color: shown != null ? AppColors.primary : AppColors.neutral500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral600)),
                  const SizedBox(height: 2),
                  Text(
                    shown ?? 'Not set',
                    // A formatted date in a fixed-width row is a classic
                    // overflow on narrow phones.
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          shown != null ? FontWeight.w600 : FontWeight.w400,
                      color: shown != null
                          ? AppColors.neutral900
                          : AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.neutral500,
                onPressed: onClear,
                tooltip: 'Clear',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    /*
        The lower bound is the job's own start date when it is already in the
        past, not today.

        A job posted last week for yesterday is still editable — the server
        deliberately drops `after_or_equal:today` on update for that reason —
        and a picker that refused to open on its current value would strand the
        employer on a form they cannot submit.
    */
    final currentStart = _startDate;
    final firstDate = isStart
        ? (currentStart != null && currentStart.isBefore(today)
            ? currentStart
            : today)
        : currentStart!;

    final initial = (isStart ? _startDate : _endDate) ?? firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        // An end date now before the start would be rejected server-side.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  /// The server stores `daily` / `hourly` / `project`; the picker shows
  /// Daily / Hourly / Project.
  String _periodToLabel(String? period) => switch (period) {
        'hourly'  => 'Hourly',
        'project' => 'Project',
        _         => 'Daily',
      };

  /// Real skills for the chosen category, from the server's taxonomy.
  ///
  /// This used to read a hardcoded map of skill *names*, which had no ids and
  /// so could never be sent — `required_skill_ids` was simply left out of the
  /// payload while the chips looked like they were doing something.
  List<SkillModel> get _availableSkills {
    if (_categoryId == null) return const [];
    return context
        .read<WorkerProfileProvider>()
        .availableSkills
        .where((s) => s.categoryId == _categoryId)
        .toList();
  }

  /// Sets both the label and the id.
  ///
  /// Only the label was set before, so the payload kept sending whichever
  /// `category_id` arrived in the route arguments. Picking a new category
  /// moved the checkmark, changed the skill chips, and reported success —
  /// while the job stayed in its original category.
  void _updateCategory(String? category, int? categoryId) {
    setState(() {
      _selectedSkillIds = [];
      _selectedCategory = category;
      _categoryId = categoryId;
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
                            _label('Salary from'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetController,
                              onChanged: (_) {
                                if (_budgetMaxController.text.trim().isNotEmpty) {
                                  _formKey.currentState?.validate();
                                }
                              },
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
                      /*
                          _budgetMaxController was declared, prefilled from the
                          job and read back on save - but no field was ever
                          bound to it, so the maximum could be neither seen nor
                          changed. Whatever the job was posted with was simply
                          written back unchanged.
                      */
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('to (optional)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetMaxController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco(
                                  hint: '1,800', prefix: '₱ '),
                              validator: (v) {
                                final raw = v?.trim() ?? '';
                                if (raw.isEmpty) return null;
                                final max =
                                    double.tryParse(raw.replaceAll(',', ''));
                                if (max == null) return 'Enter a valid amount';
                                if (max <= 0) return 'Must be greater than 0';
                                final min = double.tryParse(
                                    _budgetController.text.replaceAll(',', ''));
                                if (min != null && max < min) {
                                  return 'Cannot be below the minimum';
                                }
                                return null;
                              },
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
                  // Picker, not free text — see post_job_screen for the reason.
                  LocationPickerField(
                    controller: _locationController,
                    labelText: '',
                    hintText: 'Search barangay, city or municipality',
                    selection: _selectedLocation,
                    onSelected: (location) =>
                        setState(() => _selectedLocation = location),
                    // Text edited after choosing — drop the id so the job
                    // can't keep one place's coordinates under another's name.
                    onCleared: () => setState(() => _selectedLocation = null),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Schedule ──
              _section(
                title: 'Schedule',
                children: [
                  _dateRow(
                    label: 'Start date',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: 10),
                  _dateRow(
                    label: 'End date (optional)',
                    value: _endDate,
                    onTap: _startDate == null
                        ? null
                        : () => _pickDate(isStart: false),
                    onClear: _endDate == null
                        ? null
                        : () => setState(() => _endDate = null),
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
                // orElse: a job filed under a category that has since been
                // renamed would otherwise throw here rather than render.
                _categories.firstWhere(
                  (c) => c['name'] == _selectedCategory,
                  orElse: () => {'icon': Icons.build},
                )['icon'] as IconData,
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
                      _updateCategory(cat['name'] as String?, cat['id'] as int?);
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
        final isSel = _selectedSkillIds.contains(skill.id);
        return GestureDetector(
          onTap: () => setState(() {
            isSel
                ? _selectedSkillIds.remove(skill.id)
                : _selectedSkillIds.add(skill.id);
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
            child: Text(skill.name,
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
      AppToast.info(context, 'Please select a category');
      return;
    }

    // Without an id there is nothing to update. Previously this method faked a
    // one-second delay and then reported "Job updated successfully!" regardless
    // — the edit was never sent anywhere.
    if (_jobId == null) {
      AppToast.error(context, 'Cannot edit: this job is missing its identifier.');
      return;
    }

    setState(() => _isLoading = true);

    final jobProvider = context.read<JobProvider>();
    final budget = double.tryParse(_budgetController.text.replaceAll(',', ''));

    final budgetMax = double.tryParse(_budgetMaxController.text.replaceAll(',', ''));

    final success = await jobProvider.updateJob(_jobId!, {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      if (_categoryId != null) 'category_id': _categoryId,
      if (budget != null) 'budget_min': budget,
      /*
          Five fields the form collected and then dropped.

          The server has accepted all of them from the start — they were just
          never put in the body. So the urgent toggle, the negotiable toggle,
          the Daily/Hourly/Project picker, the maximum budget and the skill
          chips all moved on screen, reported "Job updated successfully!", and
          changed nothing.
      */
      if (budgetMax != null) 'budget_max': budgetMax,
      'budget_period': _salaryType.toLowerCase(),
      'is_urgent': _isUrgent,
      'is_negotiable': _isNegotiable,
      'required_skill_ids': _selectedSkillIds,
      'location': _locationController.text.trim(),
      // Only sent when the user re-picked; otherwise the stored value stands.
      if (_selectedLocation != null) 'location_id': _selectedLocation!.id,
      if (_selectedLocation?.latitude != null)
        'latitude': _selectedLocation!.latitude,
      if (_selectedLocation?.longitude != null)
        'longitude': _selectedLocation!.longitude,
      // Sent only when known. A job posted before scheduling existed has no
      // date, and sending an explicit null would be indistinguishable from the
      // employer clearing one — which the form offers no way to do.
      if (_startDate != null) 'start_date': JobProvider.ymd(_startDate!),
      if (_endDate != null) 'end_date': JobProvider.ymd(_endDate!),
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    AppToast.info(context, success
            ? 'Job updated successfully!'
            : jobProvider.errorMessage ?? 'Failed to update job');

    if (success) Navigator.pop(context, true);
  }
}
