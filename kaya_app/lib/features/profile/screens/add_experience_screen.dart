import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/worker_profile_provider.dart';

class AddExperienceScreen extends StatefulWidget {
  const AddExperienceScreen({super.key});

  @override
  State<AddExperienceScreen> createState() => _AddExperienceScreenState();
}

class _AddExperienceScreenState extends State<AddExperienceScreen> {
  // Check if we're in onboarding memory-only mode
  bool _inMemoryMode = false;
  List<Map<String, dynamic>> _tempExperiences = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check for arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['inMemoryMode'] == true) {
        setState(() {
          _inMemoryMode = true;
          _tempExperiences = List<Map<String, dynamic>>.from(args['experiences'] ?? []);
        });
      } else {
        context.read<WorkerProfileProvider>().fetchProfile();
      }
    });
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      if (d.contains('-')) {
        final parts = d.split('-');
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final m = int.tryParse(parts[1]) ?? 1;
        return '${months[m]} ${parts[0]}';
      }
    } catch (_) {}
    return d;
  }

  Future<void> _addExperience() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const _ExperienceFormScreen()),
    );
    if (result == null || !mounted) return;

    if (_inMemoryMode) {
      // Memory mode: add to temp list
      setState(() {
        _tempExperiences.add({
          'jobTitle': result['jobTitle'],
          'company': result['company'],
          'startDate': result['startDate'],
          'endDate': result['endDate'],
          'description': result['description'],
        });
      });
    } else {
      // Normal mode: save to DB
      final provider = context.read<WorkerProfileProvider>();
      final success = await provider.createExperience(result);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Experience saved' : (provider.errorMessage ?? 'Failed to save')),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ));
    }
  }

  Future<void> _editExperience(Map<String, dynamic> exp) async {
    // Convert DB format back to form format
    final formData = {
      'jobTitle': exp['title'] as String? ?? '',
      'company': exp['company'] as String? ?? '',
      'startDate': _fmtDateToForm(exp['start_date'] as String?),
      'endDate': exp['end_date'] != null ? _fmtDateToForm(exp['end_date'] as String?) : 'Present',
      'description': exp['description'] as String? ?? '',
    };

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => _ExperienceFormScreen(existingExp: formData)),
    );
    if (result == null || !mounted) return;

    final provider = context.read<WorkerProfileProvider>();
    final id = exp['id'] as int;
    final success = await provider.updateExperience(id, result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Experience updated' : (provider.errorMessage ?? 'Failed to update')),
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
  }

  // Convert "YYYY-MM-01" back to "M/YYYY" for the form
  String _fmtDateToForm(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      if (d.contains('-')) {
        final parts = d.split('-');
        return '${int.tryParse(parts[1]) ?? 1}/${parts[0]}';
      }
    } catch (_) {}
    return d;
  }

  Future<void> _deleteExperience(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Experience'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<WorkerProfileProvider>().deleteExperience(id);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_inMemoryMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // In memory mode, return data when back is pressed
        if (_inMemoryMode) {
          Navigator.pop(context, _tempExperiences);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () {
            if (_inMemoryMode) {
              Navigator.pop(context, _tempExperiences);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Work Experience',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        centerTitle: true,
        actions: _inMemoryMode ? [
          TextButton(
            onPressed: () => Navigator.pop(context, _tempExperiences),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ] : null,
      ),
      body: _inMemoryMode ? _buildMemoryMode() : _buildNormalMode(),
      ),
    );
  }

  Widget _buildNormalMode() {
    return Consumer<WorkerProfileProvider>(
      builder: (context, provider, _) {
        final exps = provider.experiences;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addExperience,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Experience'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (provider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (exps.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: AppColors.neutral100, borderRadius: BorderRadius.circular(12)),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.work_outline, size: 48, color: AppColors.neutral400),
                              SizedBox(height: 12),
                              Text('No experience added yet',
                                  style: TextStyle(fontSize: 15, color: AppColors.neutral600)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: exps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _expCard(exps[i]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemoryMode() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addExperience,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Experience'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_tempExperiences.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                        color: AppColors.neutral100, borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.work_outline, size: 48, color: AppColors.neutral400),
                          SizedBox(height: 12),
                          Text('No experience added yet',
                              style: TextStyle(fontSize: 15, color: AppColors.neutral600)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tempExperiences.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _tempExpCard(_tempExperiences[i], i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tempExpCard(Map<String, dynamic> exp, int index) {
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
                child: Text(exp['jobTitle'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.neutral900)),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                onPressed: () {
                  setState(() => _tempExperiences.removeAt(index));
                },
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(exp['company'] ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.neutral700)),
          const SizedBox(height: 2),
          Text('${exp['startDate']} – ${exp['endDate']}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
          if ((exp['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(exp['description'] ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _expCard(Map<String, dynamic> exp) {
    final startStr = _fmtDate(exp['start_date'] as String?);
    final endRaw = exp['end_date'] as String?;
    final endStr = endRaw != null ? _fmtDate(endRaw) : 'Present';

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
                child: Text(exp['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.neutral900)),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                onPressed: () => _editExperience(exp),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                onPressed: () => _deleteExperience(exp['id'] as int),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(exp['company'] ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.neutral700)),
          const SizedBox(height: 2),
          Text('$startStr – $endStr',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
          if ((exp['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(exp['description'] ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ── Experience Form ───────────────────────────────────────────────────────────

class _ExperienceFormScreen extends StatefulWidget {
  final Map<String, String>? existingExp;
  const _ExperienceFormScreen({this.existingExp});

  @override
  State<_ExperienceFormScreen> createState() => _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends State<_ExperienceFormScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _descCtrl;
  bool _isPresent = false;

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty &&
      _companyCtrl.text.trim().isNotEmpty &&
      _startCtrl.text.trim().isNotEmpty &&
      (_isPresent || _endCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    final e = widget.existingExp;
    _titleCtrl   = TextEditingController(text: e?['jobTitle'] ?? '');
    _companyCtrl = TextEditingController(text: e?['company'] ?? '');
    _startCtrl   = TextEditingController(text: e?['startDate'] ?? '');
    _endCtrl     = TextEditingController(text: e?['endDate'] == 'Present' ? '' : (e?['endDate'] ?? ''));
    _descCtrl    = TextEditingController(text: e?['description'] ?? '');
    _isPresent   = e?['endDate'] == 'Present';

    for (final c in [_titleCtrl, _companyCtrl, _startCtrl, _endCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _companyCtrl.dispose();
    _startCtrl.dispose(); _endCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, String label) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      helpText: label,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.neutral900),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => ctrl.text = '${picked.month}/${picked.year}');
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'jobTitle':    _titleCtrl.text.trim(),
      'company':     _companyCtrl.text.trim(),
      'startDate':   _startCtrl.text.trim(),
      'endDate':     _isPresent ? 'Present' : _endCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    });
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
        title: Text(widget.existingExp != null ? 'Edit Experience' : 'Add Experience',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(_titleCtrl, 'Job Title', 'e.g. Plumber'),
                  const SizedBox(height: 16),
                  _field(_companyCtrl, 'Company / Employer', 'e.g. ABC Construction'),
                  const SizedBox(height: 16),
                  _datePicker(_startCtrl, 'Start Date', 'Select Start Date'),
                  const SizedBox(height: 16),
                  if (!_isPresent)
                    _datePicker(_endCtrl, 'End Date', 'Select End Date'),
                  Row(
                    children: [
                      Checkbox(
                        value: _isPresent,
                        onChanged: (v) => setState(() {
                          _isPresent = v ?? false;
                          if (_isPresent) _endCtrl.clear();
                        }),
                        activeColor: AppColors.primary,
                      ),
                      const Text('Currently working here',
                          style: TextStyle(fontSize: 14, color: AppColors.neutral700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _deco('Description (Optional)', 'Describe your responsibilities...'),
                  ),
                ],
              ),
            ),
          ),
          _saveBar(),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) => TextField(
    controller: ctrl,
    textCapitalization: TextCapitalization.words,
    decoration: _deco(label, hint),
  );

  Widget _datePicker(TextEditingController ctrl, String label, String dlgTitle) => TextField(
    controller: ctrl,
    readOnly: true,
    onTap: () => _pickDate(ctrl, dlgTitle),
    decoration: _deco(label, 'MM/YYYY').copyWith(
      suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.neutral500),
    ),
  );

  InputDecoration _deco(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint,
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neutral300)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  Widget _saveBar() => Container(
    padding: const EdgeInsets.all(20),
    color: Colors.white,
    child: SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.neutral300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}
