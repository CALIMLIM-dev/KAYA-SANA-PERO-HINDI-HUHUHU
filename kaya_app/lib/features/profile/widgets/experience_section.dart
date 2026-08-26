import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/worker_profile_provider.dart';
import 'inline_expandable_row.dart';
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
  String? _open;

  bool _saving = false;
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
      _open = exp['id'];
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
      _open = 'new';
      _error = null;
      _title.clear();
      _company.clear();
      _start.clear();
      _end.clear();
      _description.clear();
    });
  }

  void _close() {
    setState(() {
      _open = null;
      _error = null;
    });
    FocusScope.of(context).unfocus();
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

  Future<void> _save(String? existingId) async {
    final title = _title.text.trim();
    final company = _company.text.trim();
    final start = _start.text.trim();

    if (title.isEmpty || company.isEmpty) {
      setState(() => _error = 'A job title and an employer are both needed.');
      return;
    }
    if (start.isEmpty) {
      setState(() => _error = 'When did you start?');
      return;
    }

    setState(() {
      _saving = true;
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

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = ok ? null : (provider.errorMessage ?? 'Could not save it.');
      if (ok) _open = null;
    });

    if (ok) FocusScope.of(context).unfocus();
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

    setState(() => _saving = true);
    final provider = context.read<WorkerProfileProvider>();
    final ok = await provider.deleteExperience(id);
    if (!mounted) return;

    setState(() {
      _saving = false;
      if (ok) _open = null;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exp in widget.experiences)
          InlineExpandableRow(
            title: exp['title'] ?? '',
            subtitle: [
              exp['company'] ?? '',
              if ((exp['start_date'] ?? '').isNotEmpty)
                '${_toFormDate(exp['start_date'])} - '
                    '${(exp['end_date'] ?? '').isEmpty ? 'Present' : _toFormDate(exp['end_date'])}',
            ].where((s) => s.isNotEmpty).join('  ·  '),
            expanded: _open == exp['id'],
            saving: _saving && _open == exp['id'],
            error: _open == exp['id'] ? _error : null,
            onToggle: () => _open == exp['id'] ? _close() : _openEntry(exp),
            onSave: () => _save(exp['id']),
            onDelete: () => _delete(exp),
            children: _fields(),
          ),

        // The add row, which is the same form with nothing in it.
        if (_open == 'new')
          InlineExpandableRow(
            title: 'New experience',
            subtitle: null,
            expanded: true,
            saving: _saving,
            error: _error,
            saveLabel: 'Add',
            onToggle: _close,
            onSave: () => _save(null),
            children: _fields(),
          )
        else
          SectionAddRow(
            label: widget.experiences.isEmpty
                ? 'Add your work experience'
                : 'Add another',
            onTap: _openNew,
          ),
      ],
    );
  }
}
