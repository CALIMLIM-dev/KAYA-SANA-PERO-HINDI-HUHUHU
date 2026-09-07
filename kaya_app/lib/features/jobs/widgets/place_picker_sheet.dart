import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/widgets/location_picker_field.dart';

/*
    Where to look for workers.

    The home directory used to be bounded by a fifty kilometre circle with a
    button to double it. A circle is not how anybody describes where they are
    willing to hire - they name a town - and fifty kilometres is a distance
    nobody drives to fit a pipe.

    City and municipality only, the same grain the employer profile uses, so
    the answer matches what the directory can filter on. The picker returns the
    chosen place; the caller decides what to do with it.
*/
Future<LocationModel?> showPlacePickerSheet(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<LocationModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _PlacePickerSheet(current: current),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet({this.current});

  final String? current;

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current ?? '');

  LocationModel? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clears the keyboard, which covers the suggestion list otherwise.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Look for workers in',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 12),
          LocationPickerField(
            controller: _controller,
            labelText: '',
            hintText: 'Search city or municipality',
            // Same grain as the employer profile: a barangay here would hide
            // every worker in the rest of the town.
            cityLevel: true,
            selection: _selected,
            onSelected: (place) => setState(() => _selected = place),
            onCleared: () => setState(() => _selected = null),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Disabled until a place is picked from the list rather than
              // typed: free text has no id, and the directory filters on the
              // id.
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: const Text('Show workers here'),
            ),
          ),
        ],
      ),
    );
  }
}
