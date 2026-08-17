import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../data/models/worker_license_model.dart';
import '../../../core/widgets/app_toast.dart';

/// Licenses screen — stored as certifications on the backend with a 'license' type flag
class AddLicensesScreen extends StatefulWidget {
  const AddLicensesScreen({super.key});

  @override
  State<AddLicensesScreen> createState() => _AddLicensesScreenState();
}

class _AddLicensesScreenState extends State<AddLicensesScreen> {
  // Licenses are stored in the same certifications list but shown separately
  // We filter by whether the title implies a license — for now show all certs here too

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkerProfileProvider>().fetchProfile();
    });
  }

  Future<void> _addLicense() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const _LicenseFormScreen()),
    );
    if (result == null || !mounted) return;

    final provider = context.read<WorkerProfileProvider>();
    
    // Convert to proper WorkerLicenseModel format
    final license = WorkerLicenseModel(
      userId: 0, // Will be set by backend
      licenseName: result['license_name'],
      licenseNumber: result['license_number'],
      issuingAuthority: result['issuing_authority'],
      issueDate: result['issue_date'] != null ? DateTime.parse(result['issue_date']) : null,
    );
    
    final success = await provider.addLicense(
      license,
      filePath: result['filePath'] as String?,
    );
    if (!mounted) return;

    AppToast.info(context, success ? 'License saved' : (provider.errorMessage ?? 'Failed to save'));
  }

  Future<void> _editLicense(WorkerLicenseModel license) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _LicenseFormScreen(existingLicense: license)),
    );
    if (result == null || !mounted) return;

    final provider = context.read<WorkerProfileProvider>();
    
    final updatedLicense = WorkerLicenseModel(
      userId: license.userId,
      licenseName: result['license_name'],
      licenseNumber: result['license_number'],
      issuingAuthority: result['issuing_authority'],
      issueDate: result['issue_date'] != null ? DateTime.parse(result['issue_date']) : null,
    );
    
    final success = await provider.updateLicense(license.id!, updatedLicense);
    if (!mounted) return;

    AppToast.info(context, success ? 'License updated' : (provider.errorMessage ?? 'Failed to update'));
  }

  Future<void> _deleteLicense(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete License'),
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
    await context.read<WorkerProfileProvider>().deleteLicense(id);
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
        title: const Text('Licenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        centerTitle: true,
      ),
      body: Consumer<WorkerProfileProvider>(
        builder: (context, provider, _) {
          final licenses = provider.licenses;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addLicense,
                          icon: const Icon(Icons.add),
                          label: const Text('Add License'),
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
                      else if (licenses.isEmpty)
                        _emptyState()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: licenses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _licenseCard(licenses[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _licenseCard(WorkerLicenseModel lic) {
    String displayDate = '';
    if (lic.issueDate != null) {
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      displayDate = '${months[lic.issueDate!.month]} ${lic.issueDate!.year}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge, color: Colors.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lic.licenseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(lic.issuingAuthority,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
                if (displayDate.isNotEmpty)
                  Text('Issued: $displayDate',
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
            onPressed: () => _editLicense(lic),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
            onPressed: () => _deleteLicense(lic.id!),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(12)),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 48, color: AppColors.neutral400),
              SizedBox(height: 12),
              Text('No licenses added yet', style: TextStyle(fontSize: 15, color: AppColors.neutral600)),
            ],
          ),
        ),
      );
}

// ── License Form Screen ───────────────────────────────────────────────────────

class _LicenseFormScreen extends StatefulWidget {
  final WorkerLicenseModel? existingLicense;
  const _LicenseFormScreen({this.existingLicense});

  @override
  State<_LicenseFormScreen> createState() => _LicenseFormScreenState();
}

class _LicenseFormScreenState extends State<_LicenseFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _authorityCtrl;
  late final TextEditingController _dateCtrl;
  String? _filePath;
  String? _fileName;
  String? _existingDocUrl; // For displaying existing photo in edit mode
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final lic = widget.existingLicense;
    _nameCtrl = TextEditingController(text: lic?.licenseName ?? '');
    _authorityCtrl = TextEditingController(text: lic?.issuingAuthority ?? '');
    _dateCtrl = TextEditingController(
      text: lic?.issueDate != null 
        ? '${lic!.issueDate!.year}-${lic.issueDate!.month.toString().padLeft(2, '0')}-${lic.issueDate!.day.toString().padLeft(2, '0')}'
        : '',
    );
    _existingDocUrl = lic?.documentPath; // Load existing document URL
    _confirmed = widget.existingLicense != null; // Skip confirmation on edit
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _authorityCtrl.text.trim().isNotEmpty &&
      _dateCtrl.text.trim().isNotEmpty &&
      (widget.existingLicense != null || (_filePath != null && _confirmed));

  @override
  void dispose() {
    _nameCtrl.dispose();
    _authorityCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
        _fileName = result.files.first.name;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.neutral900,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'license_name': _nameCtrl.text.trim(),
      'license_number': 'N/A', // Not collected, use placeholder
      'issuing_authority': _authorityCtrl.text.trim(),
      'issue_date': _dateCtrl.text.trim(),
      'filePath': _filePath,
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
        title: Text(widget.existingLicense != null ? 'Edit License' : 'Add License',
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
                  _field(_nameCtrl, 'License Name', 'e.g. Licensed Plumber'),
                  const SizedBox(height: 16),
                  _field(_authorityCtrl, 'Issued By', 'e.g. DOLE, PRC'),
                  const SizedBox(height: 16),
                  _field(_dateCtrl, 'Date Issued', 'YYYY-MM-DD',
                      readOnly: true, onTap: _selectDate,
                      suffix: const Icon(Icons.calendar_today, size: 18)),
                  const SizedBox(height: 24),
                  _uploadBox(),
                  if (_filePath != null) ...[
                    const SizedBox(height: 16),
                    _confirmCheck(),
                  ],
                ],
              ),
            ),
          ),
          _saveBar(),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {bool readOnly = false, VoidCallback? onTap, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: (_) => setState(() {}),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label, hintText: hint, suffixIcon: suffix,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _uploadBox() {
    // Show existing document if in edit mode and no new file selected
    final hasExisting = _existingDocUrl != null && _existingDocUrl!.isNotEmpty;
    final hasNewFile = _fileName != null;
    
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (hasNewFile || hasExisting) ? AppColors.success : AppColors.neutral300,
            width: (hasNewFile || hasExisting) ? 2 : 1.5,
          ),
        ),
        child: (hasNewFile || hasExisting)
            ? Column(
                children: [
                  // Image preview
                  if (hasNewFile && _isImage()) ...[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.file(
                        File(_filePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ] else if (hasNewFile && !_isImage()) ...[
                    // New PDF — show icon
                    Container(
                      height: 140,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.error),
                          const SizedBox(height: 8),
                          Text(_fileName ?? '',
                              style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ] else if (hasExisting && !hasNewFile) ...[
                    // Show existing document
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.network(
                        // Was a hardcoded tunnel URL, so an existing document
                        // stopped rendering the moment the tunnel changed.
                        ApiClient.fileUrl(_existingDocUrl),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 56, color: AppColors.neutral400),
                              SizedBox(height: 8),
                              Text('Existing document',
                                  style: TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasNewFile ? (_fileName ?? 'Document selected') : 'Existing document',
                            style: const TextStyle(fontSize: 13.5, color: AppColors.success),
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _filePath = null;
                            _fileName = null;
                            _confirmed = widget.existingLicense != null; // Keep confirmed in edit mode
                          }),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  const Icon(Icons.upload_file_outlined, size: 40, color: AppColors.neutral400),
                  const SizedBox(height: 12),
                  Text(
                    widget.existingLicense != null ? 'Tap to change document' : 'Tap to upload license',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral700),
                  ),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG, or PDF — max 5MB',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral400)),
                ]),
              ),
      ),
    );
  }

  bool _isImage() {
    if (_fileName == null) return false;
    final ext = _fileName!.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(ext);
  }

  Widget _confirmCheck() {
    return GestureDetector(
      onTap: () => setState(() => _confirmed = !_confirmed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _confirmed ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _confirmed ? AppColors.primary : AppColors.neutral400),
            ),
            child: _confirmed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'I confirm this document is genuine. Submitting fake documents will result in permanent account ban and may be reported to authorities.',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
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
}
