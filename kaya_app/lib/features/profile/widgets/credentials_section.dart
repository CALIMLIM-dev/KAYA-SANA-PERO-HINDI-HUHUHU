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
  // _open / _addingNew are gone: which entry is being edited is the sheet's
  // own business now, not a flag the section has to hold and keep in step.
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

  /// Returns whether it saved, so the editor sheet knows to close.
  Future<bool> _save({int? id}) async {
    final name = _name.text.trim();
    final issuer = _issuer.text.trim();

    if (name.isEmpty || issuer.isEmpty) {
      setState(() => _error = _isLicence
          ? 'A licence name and issuing authority are both needed.'
          : 'A certificate name and issuing organisation are both needed.');
      return false;
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

    if (!mounted) return false;

    setState(() {
      _saving = false;
      _error = ok ? null : (provider.errorMessage ?? 'Could not save it.');
      if (ok) _reset();
    });

    if (ok) FocusScope.of(context).unfocus();

    return ok;
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
      // Nothing to collapse any more — just clear the form state.
      if (ok) _reset();
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

  /*
      The editor is a sheet over the profile, not a row that grows.

      Adding a certificate used to expand the row in place, so the form
      appeared halfway down a long scrolling profile, pushed everything
      below it out of view, and left the save button wherever the expansion
      happened to end. On a filled-in profile you had to hunt for the thing
      you had just opened.

      A sheet puts the form in one predictable place with the profile still
      behind it, which is what makes it read as "adding a row here" rather
      than as a new screen. Same treatment the credential pages already got.
  */
  Future<void> _showEditor({int? id, required String heading}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var busy = false;
        String? error;

        return StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
            // Lifts with the keyboard: this form is all text fields, and a
            // sheet that does not lift hides the one being typed into.
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.neutral300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(heading,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900)),
                      const SizedBox(height: 16),
                      ..._fields(),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  setSheet(() => busy = true);
                                  final ok = await _save(id: id);
                                  if (!sheetContext.mounted) return;
                                  if (ok) {
                                    Navigator.pop(sheetContext);
                                  } else {
                                    setSheet(() {
                                      busy = false;
                                      error = _error;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(id == null ? 'Add' : 'Save',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Whether it saved or was dismissed, the next open starts clean.
    if (mounted) setState(_reset);
  }

  List<Widget> _fields() => [
        InlineField(
          controller: _name,
          label: _isLicence ? 'Licence name' : 'Certificate name',
        ),
        InlineField(
          controller: _issuer,
          label: _isLicence ? 'Issuing authority' : 'Issuing organisation',
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
          CredentialRow(
            title: e.title,
            subtitle: e.issuer,
            hasDocument: (e.doc ?? '').isNotEmpty,
            onTap: () {
              _reset();
              _name.text = e.title;
              _issuer.text = e.issuer;
              _reference.text = e.reference == 'N/A' ? '' : e.reference;
              _existingDoc = e.doc;
              _showEditor(
                id: e.id,
                heading: _isLicence ? 'Edit licence' : 'Edit certificate',
              );
            },
            onDelete: e.id == null ? null : () => _delete(e.id!, e.title),
          ),
        SectionAddRow(
          label: entries.isEmpty
              ? (_isLicence ? 'Add a licence' : 'Add a certificate')
              : 'Add another',
          onTap: () {
            _reset();
            _showEditor(
              heading: _isLicence ? 'New licence' : 'New certificate',
            );
          },
        ),
      ],
    );
  }
}

/*
    One saved credential on the profile.

    Replaces InlineExpandableRow here: the row no longer holds a form, so it
    only has to say what it is and open the editor. Delete stays on the row
    because it acts on this entry and needs no form to do it.
*/
class CredentialRow extends StatelessWidget {
  const CredentialRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hasDocument,
    required this.onTap,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool hasDocument;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.neutral600)),
                  ],
                ],
              ),
            ),
            if (hasDocument)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.attach_file,
                    size: 16, color: AppColors.neutral400),
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.neutral400),
                onPressed: onDelete,
              ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
