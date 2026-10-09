import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    The days a worker works and how far they will travel.

    Matching holds both against every job: the job's dates against the
    days, the distance against the range (JobMatchService::criteria). Drawn
    like InlineEditRow so they sit among the other profile rows.
*/

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon-Fri", "Every day", "Mon, Wed, Sat".
String daysLabel(List<int> days) {
  if (days.isEmpty) return '';
  final sorted = [...days]..sort();
  if (sorted.length == 7) return 'Every day';
  if (sorted.join() == '12345') return 'Mon-Fri';
  if (sorted.join() == '123456') return 'Mon-Sat';
  return sorted.map((d) => _dayNames[d - 1]).join(', ');
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = (value ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: AppColors.neutral500)),
                      const SizedBox(height: 3),
                      Text(filled ? value! : 'Not set',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: filled ? AppColors.neutral900 : AppColors.primary,
                            fontWeight: filled ? FontWeight.normal : FontWeight.w600,
                          )),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(filled ? Icons.edit_outlined : Icons.add,
                      size: 19, color: filled ? AppColors.neutral400 : AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a sheet of chips and saves on Save. [multi] picks several.
Future<void> _pickSheet<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required Set<T> initial,
  required bool multi,
  required Future<String?> Function(Set<T>) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ChipSheet<T>(
        title: title, options: options, initial: initial, multi: multi, onSave: onSave),
  );
}

class _ChipSheet<T> extends StatefulWidget {
  const _ChipSheet({
    required this.title,
    required this.options,
    required this.initial,
    required this.multi,
    required this.onSave,
  });

  final String title;
  final Map<T, String> options;
  final Set<T> initial;
  final bool multi;
  final Future<String?> Function(Set<T>) onSave;

  @override
  State<_ChipSheet<T>> createState() => _ChipSheetState<T>();
}

class _ChipSheetState<T> extends State<_ChipSheet<T>> {
  late final Set<T> _picked = {...widget.initial};
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    if (_picked.isEmpty) {
      setState(() => _error = 'Choose at least one.');
      return;
    }
    setState(() => _saving = true);
    final error = await widget.onSave(_picked);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in widget.options.entries)
                  widget.multi
                      ? FilterChip(
                          label: Text(e.value),
                          selected: _picked.contains(e.key),
                          onSelected: (on) => setState(() {
                            _error = null;
                            on ? _picked.add(e.key) : _picked.remove(e.key);
                          }),
                        )
                      : ChoiceChip(
                          label: Text(e.value),
                          selected: _picked.contains(e.key),
                          onSelected: (_) => setState(() {
                            _error = null;
                            _picked
                              ..clear()
                              ..add(e.key);
                          }),
                        ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkDaysRow extends StatelessWidget {
  const WorkDaysRow({super.key, required this.days, required this.onSave});

  final List<int> days;
  final Future<String?> Function(List<int> days) onSave;

  @override
  Widget build(BuildContext context) => _PrefRow(
        label: 'Days you can work',
        value: daysLabel(days),
        onTap: () => _pickSheet<int>(
          context,
          title: 'Days you can work',
          options: {for (var i = 1; i <= 7; i++) i: _dayNames[i - 1]},
          initial: days.toSet(),
          multi: true,
          onSave: (picked) => onSave(picked.toList()..sort()),
        ),
      );
}

class TravelRangeRow extends StatelessWidget {
  const TravelRangeRow({super.key, required this.km, required this.onSave});

  final int? km;
  final Future<String?> Function(int km) onSave;

  static const ranges = [5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) => _PrefRow(
        label: 'How far you can travel',
        value: km == null ? null : 'Up to $km km',
        onTap: () => _pickSheet<int>(
          context,
          title: 'How far you can travel',
          options: {for (final r in ranges) r: '$r km'},
          initial: {?km},
          multi: false,
          onSave: (picked) => onSave(picked.first),
        ),
      );
}
