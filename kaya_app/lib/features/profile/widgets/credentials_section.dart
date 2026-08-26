import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/worker_certification_model.dart';
import '../../../data/models/worker_license_model.dart';
import '../../../providers/worker_profile_provider.dart';
import 'inline_expandable_row.dart';
import 'section_add_row.dart';

/// Which kind of credential a section is showing.
///
/// Licences and certifications are the same shape - a name, an issuer, a date
/// and a scanned document - and were two near-identical screens. One widget
/// with a flag beats two files that drift apart.
enum CredentialKind { licence, certification }

/*
    Licences and certifications, edited on the profile.

    Both used to be a read-only list plus a separate screen, and the separate
    screen is where the document bug lived: it let you pick a replacement file
    that was then silently discarded. Editing them here means one save path
    instead of two.

    The document is the one part that cannot be a text field. It stays a button
    inside the expanded form, which is honest about what it does - it opens the
    file picker - and shows what is already attached, including telling a PDF
    apart from a photo rather than trying to draw one as the other.
*/
class CredentialsSection extends StatefulWidget {
  const CredentialsSection({super.key, required this.kind});

  final CredentialKind kind;

  @override
  State<CredentialsSection> createState() => _CredentialsSectionState();
}

class _CredentialsSectionState extends State<CredentialsSection> {
  int? _open;
  bool _addingNew = false;
  bool _saving = false;
  String? _error;

  final _name = TextEditingController();
  final _issuer = TextEditingController();
  final _reference = TextEditingController();

  String? _filePath;
  String? _fileName;
  String? _existingDoc;

  bool get _isLicence => widget.kind == CredentialKind.licence;

  @override
  void dispose() {
    _name.dispose();
    _issuer.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _reset() {
    _name.clear();
    _issuer.clear();
    _reference.clear();
    _filePath = null;
    _fileName = null;
    _existingDoc = null;
    _error = null;
  }

  void _close() {
    setState(() {
      _open = null;
      _addingNew = false;
      _reset();
    });
    FocusScope.of(context).unfocus();
  }

  void _openNew() {
    setState(() {
      _reset();
      _open = null;
      _addingNew = true;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _filePath = result.files.first.path;
      _fileName = result.files.first.name;
    });
  }

  Future<void> _save({int? id}) async {
    final name = _name.text.trim();
    final issuer = _issuer.text.trim();

    if (name.isEmpty || issuer.isEmpty) {
      setState(() => _error = _isLicence
          ? 'A licence name and issuing authority are both needed.'
          : 'A certificate name and issuing organisation are both needed.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final provider = context.read<WorkerProfileProvider>();
    bool ok;

    if (_isLicence) {
      final model = WorkerLicenseModel(
        userId: 0, // set by the server from the token
        licenseName: name,
        licenseNumber:
            _reference.text.trim().isEmpty ? 'N/A' : _reference.text.trim(),
        issuingAuthority: issuer,
      );
      ok = id == null
          ? await provider.addLicense(model, filePath: _filePath)
          : await provider.updateLicense(id, model, filePath: _filePath);
    } else {
      final model = WorkerCertificationModel(
        userId: 0,
        certificationName: name,
        issuingOrganization: issuer,
        credentialId:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      );
      ok = id == null
          ? await provider.addCertification(model, filePath: _filePath)
          : await provider.updateCertification(id, model, filePath: _filePath);
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = ok ? null : (provider.errorMessage ?? 'Could not save it.');
      if (ok) {
        _open = null;
        _addingNew = false;
        _reset();
      }
    });

    if (ok) FocusScope.of(context).unfocus();
  }

  Future<void> _delete(int id, String label) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isLicence ? 'Remove this licence?' : 'Remove this certificate?'),
        content: Text('"$label" comes off your profile, along with its document.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _saving = true);
    final provider = context.read<WorkerProfileProvider>();
    final ok = _isLicence
        ? await provider.deleteLicense(id)
        : await provider.deleteCertification(id);
    if (!mounted) return;

    setState(() {
      _saving = false;
      if (ok) _close();
    });

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not remove it.');
    }
  }

  /// What is attached now, and how to change it.
  Widget _documentField() {
    final hasNew = _filePath != null;
    final hasExisting = (_existingDoc ?? '').isNotEmpty;
    final isPdf = hasNew
        ? _fileName!.toLowerCase().endsWith('.pdf')
        : (_existingDoc ?? '').toLowerCase().endsWith('.pdf');

    final label = hasNew
        ? _fileName!
        : hasExisting
            ? _existingDoc!.split('/').last
            : 'No document attached';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _saving ? null : _pickFile,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasNew
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.neutral300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                (hasNew || hasExisting)
                    ? (isPdf ? Icons.picture_as_pdf : Icons.image_outlined)
                    : Icons.upload_file,
                size: 20,
                color: (hasNew || hasExisting)
                    ? (isPdf ? AppColors.error : AppColors.primary)
                    : AppColors.neutral500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.neutral900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasNew
                          ? 'Replaces the current one when you save'
                          : hasExisting
                              ? 'Tap to replace'
                              : 'Tap to attach a photo or PDF',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.neutral500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() => [
        InlineField(
          controller: _name,
          label: _isLicence ? 'Licence name' : 'Certificate name',
          hint: _isLicence ? 'Professional Driver\'s Licence' : 'NC II Welding',
        ),
        InlineField(
          controller: _issuer,
          label: _isLicence ? 'Issuing authority' : 'Issuing organisation',
          hint: _isLicence ? 'LTO, PRC' : 'TESDA',
        ),
        InlineField(
          controller: _reference,
          label: _isLicence ? 'Licence number' : 'Credential ID',
          hint: 'Optional',
        ),
        _documentField(),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkerProfileProvider>();

    final entries = _isLicence
        ? provider.licenses
            .map((l) => (
                  id: l.id,
                  title: l.licenseName,
                  issuer: l.issuingAuthority,
                  reference: l.licenseNumber,
                  doc: l.documentPath,
                ))
            .toList()
        : provider.certifications
            .map((c) => (
                  id: c.id,
                  title: c.certificationName,
                  issuer: c.issuingOrganization,
                  reference: c.credentialId ?? '',
                  doc: c.documentPath,
                ))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          InlineExpandableRow(
            title: e.title,
            subtitle: e.issuer,
            expanded: _open == e.id,
            saving: _saving && _open == e.id,
            error: _open == e.id ? _error : null,
            onToggle: () {
              if (_open == e.id) {
                _close();
              } else {
                setState(() {
                  _reset();
                  _addingNew = false;
                  _open = e.id;
                  _name.text = e.title;
                  _issuer.text = e.issuer;
                  _reference.text = e.reference == 'N/A' ? '' : e.reference;
                  _existingDoc = e.doc;
                });
              }
            },
            onSave: () => _save(id: e.id),
            onDelete: e.id == null ? null : () => _delete(e.id!, e.title),
            children: _fields(),
          ),

        if (_addingNew)
          InlineExpandableRow(
            title: _isLicence ? 'New licence' : 'New certificate',
            subtitle: null,
            expanded: true,
            saving: _saving,
            error: _error,
            saveLabel: 'Add',
            onToggle: _close,
            onSave: () => _save(),
            children: _fields(),
          )
        else
          SectionAddRow(
            label: entries.isEmpty
                ? (_isLicence ? 'Add a licence' : 'Add a certificate')
                : 'Add another',
            onTap: _openNew,
          ),
      ],
    );
  }
}
