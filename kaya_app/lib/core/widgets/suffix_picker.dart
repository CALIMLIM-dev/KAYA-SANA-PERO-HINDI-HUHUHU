import 'package:flutter/material.dart';

/*
    The name suffix, picked rather than typed.

    It was a text box, and testers typed "N/A" into it - so names read
    "Harvey N. Reyes N/A". Picked from the suffixes Filipino names use, with
    None first, it stays optional and can only be a real one. Writes into the
    same controller the form already saves from.
*/
class SuffixPicker extends StatelessWidget {
  const SuffixPicker({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final VoidCallback? onChanged;

  static const options = ['', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

  /// "jr", "JR." and "Jr" are one suffix; anything else is none.
  static String normalise(String typed) {
    final key = typed.trim().toLowerCase().replaceAll('.', '');
    return options.firstWhere((o) => o.toLowerCase().replaceAll('.', '') == key, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    final current = normalise(controller.text);

    return DropdownButtonFormField<String>(
      // A prefill that arrives after the first frame has to show.
      key: ValueKey(current),
      // Empty until picked, so the label sits inside like the boxes above.
      initialValue: current.isEmpty ? null : current,
      isExpanded: true,
      decoration: decoration,
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'None' : o)),
      ],
      onChanged: enabled
          ? (value) {
              controller.text = value ?? '';
              onChanged?.call();
            }
          : null,
    );
  }
}
