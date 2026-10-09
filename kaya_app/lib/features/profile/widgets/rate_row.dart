import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/*
    What the worker expects to be paid.

    The server has carried a rate since the matching work - every card,
    the directory filter and the public profile show it - and nothing in
    the app could set one. A complete job seeker profile now states either
    a figure or "to be discussed", so this is the row that says which.

    Drawn like InlineEditRow so it sits among the other rows unnoticed;
    the editing happens in a sheet because it is three inputs, not one.
*/
class RateRow extends StatelessWidget {
  const RateRow({
    super.key,
    required this.label,
    required this.rateMin,
    required this.rateMax,
    required this.rateUnit,
    required this.byAgreement,
    required this.onSave,
  });

  /// The server's phrasing, e.g. "P500-P800/day" or "Rate to be discussed".
  final String? label;
  final double? rateMin;
  final double? rateMax;
  final String? rateUnit;
  final bool byAgreement;

  /// Returns an error message, or null when the save worked.
  final Future<String?> Function(RateChoice choice) onSave;

  @override
  Widget build(BuildContext context) {
    final filled = (label ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
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
                      const Text(
                        'Expected rate',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: AppColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        filled ? label! : 'Not set',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: filled ? AppColors.neutral900 : AppColors.primary,
                          fontWeight: filled ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    filled ? Icons.edit_outlined : Icons.add,
                    size: 19,
                    color: filled ? AppColors.neutral400 : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RateSheet(
        rateMin: rateMin,
        rateMax: rateMax,
        rateUnit: rateUnit,
        byAgreement: byAgreement,
        onSave: onSave,
      ),
    );
  }
}

/// What the sheet hands back: a figure, or "to be discussed".
class RateChoice {
  const RateChoice.figure({required double this.min, this.max, required this.unit})
      : byAgreement = false;
  const RateChoice.byAgreement()
      : byAgreement = true,
        min = null,
        max = null,
        unit = 'day';

  final bool byAgreement;
  final double? min;
  final double? max;
  final String unit;
}

class RateSheet extends StatefulWidget {
  const RateSheet({
    super.key,
    required this.rateMin,
    required this.rateMax,
    required this.rateUnit,
    required this.byAgreement,
    required this.onSave,
  });

  final double? rateMin;
  final double? rateMax;
  final String? rateUnit;
  final bool byAgreement;
  final Future<String?> Function(RateChoice choice) onSave;

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  late bool _byAgreement = widget.byAgreement;
  late String _unit = widget.rateUnit ?? 'day';
  late final _min = TextEditingController(text: _plain(widget.rateMin));
  late final _max = TextEditingController(text: _plain(widget.rateMax));
  String? _error;
  bool _saving = false;

  static const _units = {'day': 'Per day', 'hour': 'Per hour', 'project': 'Per contract'};

  static String _plain(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    RateChoice choice;
    if (_byAgreement) {
      choice = const RateChoice.byAgreement();
    } else {
      final min = double.tryParse(_min.text.trim());
      final max = _max.text.trim().isEmpty ? null : double.tryParse(_max.text.trim());
      if (min == null || min <= 0) {
        setState(() => _error = 'Enter the least you would take, in pesos.');
        return;
      }
      if (max != null && max < min) {
        setState(() => _error = 'The upper figure cannot be below the lower one.');
        return;
      }
      choice = RateChoice.figure(min: min, max: max, unit: _unit);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(choice);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expected rate',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text(
              'Hirers see this on your card. Choose "To be discussed" if you price each job after seeing it.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral600),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('A rate'),
                  selected: !_byAgreement,
                  onSelected: (_) => setState(() => _byAgreement = false),
                ),
                ChoiceChip(
                  label: const Text('To be discussed'),
                  selected: _byAgreement,
                  onSelected: (_) => setState(() => _byAgreement = true),
                ),
              ],
            ),
            if (!_byAgreement) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _amount(_min, 'From (PHP)')),
                  const SizedBox(width: 10),
                  Expanded(child: _amount(_max, 'Up to (optional)')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _units.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _unit == e.key,
                      onSelected: (_) => setState(() => _unit = e.key),
                    ),
                ],
              ),
            ],
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
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amount(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}
