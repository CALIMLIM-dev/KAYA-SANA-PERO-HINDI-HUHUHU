import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/worker_profile_provider.dart';
import 'inline_expandable_row.dart';
import 'credentials_section.dart';
import 'section_add_row.dart';

/*
    Work history, edited on the profile.

    This was a read-only list with one tap target that opened a separate
    screen. Correcting a misspelt employer meant leaving the profile, finding
    the entry again in a second list, editing it, saving, and coming back.

    Now each entry opens into its own fields where it sits, and there is a row
    at the bottom for adding one. The dates use a picker rather than a text
    box, because the provider expects M/YYYY and nobody types that reliably.
*/
class ExperienceSection extends StatefulWidget {
  const ExperienceSection({super.key, required this.experiences});

  /// The provider's list: id, title, company, start_date, end_date,
  /// description - all as strings, dates as YYYY-MM-DD.
  final List<Map<String, String>> experiences;

  @override
  State<ExperienceSection> createState() => _ExperienceSectionState();
}

class _ExperienceSectionState extends State<ExperienceSection> {
  /// The entry currently open, by id. 'new' is the add form.
  // Which entry is open is the sheet's business now, not a flag here.

  // Busy state lives in the editor sheet now — it is what shows the spinner.
  String? _error;

  final _title = TextEditingController();
  final _company = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _start.dispose();
    _end.dispose();
    _description.dispose();
    super.dispose();
  }

  /// "2024-03-01" as stored becomes "3/2024" as the provider wants it back.
  String _toFormDate(String? stored) {
    if (stored == null || stored.isEmpty) return '';
    final parts = stored.split('-');
    if (parts.length < 2) return '';
    final month = int.tryParse(parts[1]);
    return month == null ? '' : '$month/${parts[0]}';
  }

  void _openEntry(Map<String, String> exp) {
    setState(() {
      _error = null;
      _title.text = exp['title'] ?? '';
      _company.text = exp['company'] ?? '';
      _start.text = _toFormDate(exp['start_date']);
      _end.text = _toFormDate(exp['end_date']);
      _description.text = exp['description'] ?? '';
    });
  }

  void _openNew() {
    setState(() {
      _error = null;
      _title.clear();
      _company.clear();
      _start.clear();
      _end.clear();
      _description.clear();
    });
  }

  Future<void> _pickDate(TextEditingController target) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1960),
      lastDate: now,
      helpText: 'Pick a month',
    );
    if (picked == null) return;
    setState(() => target.text = '${picked.month}/${picked.year}');
  }

  /// Returns whether it saved, so the editor sheet knows to close.
  Future<bool> _save(String? existingId) async {
    final title = _title.text.trim();
    final company = _company.text.trim();
    final start = _start.text.trim();

    if (title.isEmpty || company.isEmpty) {
      setState(() => _error = 'A job title and an employer are both needed.');
      return false;
    }
    if (start.isEmpty) {
      setState(() => _error = 'When did you start?');
      return false;
    }

    setState(() {
      _error = null;
    });

    final provider = context.read<WorkerProfileProvider>();
    final payload = <String, dynamic>{
      'jobTitle': title,
      'company': company,
      'startDate': start,
      // An empty end date means the job is current, which is what the
      // provider reads 'Present' as.
      'endDate': _end.text.trim().isEmpty ? 'Present' : _end.text.trim(),
      'description': _description.text.trim(),
    };

    final ok = existingId == null
        ? await provider.createExperience(payload)
        : await provider.updateExperience(int.parse(existingId), payload);

    if (!mounted) return false;

    setState(() {
      _error = ok ? null : (provider.errorMessage ?? 'Could not save it.');
    });

    if (ok) FocusScope.of(context).unfocus();

    return ok;
  }

  Future<void> _delete(Map<String, String> exp) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this experience?'),
        content: Text('"${exp['title'] ?? 'This entry'}" comes off your profile.'),
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

    // Stored as a string by the provider, so this needs parsing rather than a
    // cast - an `as int` here silently did nothing.
    final id = int.tryParse(exp['id'] ?? '');
    if (id == null) return;

    final provider = context.read<WorkerProfileProvider>();
    final ok = await provider.deleteExperience(id);
    if (!mounted) return;

    setState(() {
    });

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not remove it.');
    }
  }

  List<Widget> _fields() => [
        InlineField(
          controller: _title,
          label: 'Job title',
        ),
        InlineField(
          controller: _company,
          label: 'Employer',
        ),
        Row(
          children: [
            Expanded(
              child: InlineField(
                controller: _start,
                label: 'Started',
                hint: 'M/YYYY',
                readOnly: true,
                onTap: () => _pickDate(_start),
                suffix: const Icon(Icons.calendar_today, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InlineField(
                controller: _end,
                label: 'Ended',
                hint: 'Leave empty if current',
                readOnly: true,
                onTap: () => _pickDate(_end),
                suffix: _end.text.isEmpty
                    ? const Icon(Icons.calendar_today, size: 16)
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _end.clear()),
                        tooltip: 'Still working here',
                      ),
              ),
            ),
          ],
        ),
        InlineField(
          controller: _description,
          label: 'What you did',
          hint: 'Optional',
          maxLines: 3,
        ),
      ];

  /*
      The editor is a sheet over the profile, not a row that grows.

      Same reason as the credentials section beside it: expanding in place
      put the form halfway down a long scrolling profile and pushed the rest
      out of view, so the save button ended up wherever the expansion
      happened to finish.
  */
  Future<void> _showEditor({String? id, required String heading}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var busy = false;
        String? error;

        return StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
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
                                  final ok = await _save(id);
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

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exp in widget.experiences)
          CredentialRow(
            title: exp['title'] ?? '',
            subtitle: [
              exp['company'] ?? '',
              if ((exp['start_date'] ?? '').isNotEmpty)
                '${_toFormDate(exp['start_date'])} - '
                    '${(exp['end_date'] ?? '').isEmpty ? 'Present' : _toFormDate(exp['end_date'])}',
            ].where((s) => s.isNotEmpty).join('  ·  '),
            hasDocument: false,
            onTap: () {
              _openEntry(exp);
              _showEditor(id: exp['id'], heading: 'Edit experience');
            },
            onDelete: () => _delete(exp),
          ),
        SectionAddRow(
          label: widget.experiences.isEmpty
              ? 'Add your work experience'
              : 'Add another',
          onTap: () {
            _openNew();
            _showEditor(heading: 'New experience');
          },
        ),
      ],
    );
  }
}
