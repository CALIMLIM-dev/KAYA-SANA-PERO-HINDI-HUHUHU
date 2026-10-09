import 'package:flutter/material.dart';

/*
    How much experience the job asks for, as a hiring criterion.

    Matching holds each worker's years against it and says so on their
    card ("2 years of experience (asks 3+)"). Any leaves it out.
*/
class ExperienceNeededPicker extends StatelessWidget {
  const ExperienceNeededPicker({super.key, required this.value, required this.onChanged});

  /// Years; null or 0 means any.
  final int? value;
  final ValueChanged<int?> onChanged;

  static const options = <int?, String>{
    null: 'Any',
    1: '1+ year',
    2: '2+ years',
    3: '3+ years',
    5: '5+ years',
  };

  @override
  Widget build(BuildContext context) {
    final current = (value == null || value == 0) ? null : value;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: current == e.key,
            onSelected: (_) => onChanged(e.key),
          ),
      ],
    );
  }
}
