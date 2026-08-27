import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/widgets/location_picker_field.dart';

/// Sets a worker's base location: the PSGC place plus an exact pin.
///
/// The separate free-text "Barangay" box that used to live here is gone —
/// the picker itself now searches barangays, so two fields meant the label
/// ("$barangay, $city") could disagree with the place actually selected.
///
/// Pops with { label, location_id, latitude, longitude }.
class AddLocationScreen extends StatefulWidget {
  /// Currently saved location label, e.g. "Urdaneta City, Pangasinan".
  final String? initialValue;
  const AddLocationScreen({super.key, this.initialValue});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  late final TextEditingController _locationCtrl;

  /// The PSGC row behind the field. Returning only the display string left the
  /// profile with no location_id and therefore no coordinates, which silently
  /// disabled every distance figure for that worker.
  LocationModel? _selectedLocation;

  double? _pinnedLat;
  double? _pinnedLng;

  @override
  void initState() {
    super.initState();
    _locationCtrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  /// Both a real place and a pin are required — a saved label with no
  /// coordinates is what made "km away" read 0 for everyone in a town.
  bool get _canSave =>
      _selectedLocation != null && _pinnedLat != null && _pinnedLng != null;

  void _save() {
    if (_selectedLocation == null) {
      AppToast.info(context, 'Pick your location from the suggestions');
      return;
    }
    if (_pinnedLat == null || _pinnedLng == null) {
      AppToast.info(context, 'Pin your exact location on the map');
      return;
    }

    Navigator.pop(context, {
      'label': _selectedLocation!.displayName,
      'location_id': _selectedLocation!.id,
      'latitude': _pinnedLat,
      'longitude': _pinnedLng,
    });
  }

  Future<void> _openPinPicker() async {
    final result = await Navigator.pushNamed(
      context,
      '/pin-location',
      arguments: {
        'latitude': _pinnedLat ?? _selectedLocation?.latitude,
        'longitude': _pinnedLng ?? _selectedLocation?.longitude,
        'label': _selectedLocation?.displayName,
      },
    );

    if (result is! Map || !mounted) return;

    setState(() {
      _pinnedLat = (result['latitude'] as num?)?.toDouble();
      _pinnedLng = (result['longitude'] as num?)?.toDouble();
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
        title: Text(
          widget.initialValue != null ? 'Edit Location' : 'Add Your Location',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('Where are you located?',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  const Text(
                      'Employers see how far you are from a job, so this needs '
                      'to be accurate.',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppColors.neutral600,
                          height: 1.5)),
                  const SizedBox(height: 28),

                  LocationPickerField(
                    controller: _locationCtrl,
                    labelText: 'Barangay, City or Municipality *',
                    hintText: 'Search your barangay or city',
                    selection: _selectedLocation,
                    onSelected: (loc) => setState(() {
                      _selectedLocation = loc;
                      // A new place invalidates a pin set for the old one.
                      _pinnedLat = null;
                      _pinnedLng = null;
                    }),
                    onCleared: () => setState(() {
                      _selectedLocation = null;
                      _pinnedLat = null;
                      _pinnedLng = null;
                    }),
                  ),

                  const SizedBox(height: 16),
                  _buildPinRow(),
                ],
              ),
            ),
          ),
          _saveBar(_canSave, _save),
        ],
      ),
    );
  }

  /// The same small pin control used on the profile, the setup flow and the
  /// job form. One action, one look, wherever it appears.
  Widget _buildPinRow() {
    final hasPin = _pinnedLat != null && _pinnedLng != null;
    final canPin = _selectedLocation != null;

    final tint = !canPin
        ? AppColors.neutral400
        : (hasPin ? AppColors.success : AppColors.primary);

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: canPin ? _openPinPicker : null,
            icon: Icon(
              hasPin ? Icons.where_to_vote : Icons.add_location_alt_outlined,
              size: 18,
            ),
            label: Text(hasPin ? 'Pinned' : 'Pin location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tint,
              side: BorderSide(color: tint.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasPin)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.neutral500,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              tooltip: 'Remove pin',
              onPressed: () => setState(() {
                _pinnedLat = null;
                _pinnedLng = null;
              }),
            ),
        ],
      ),
    );
  }
}

Widget _saveBar(bool enabled, VoidCallback onSave) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5))
      ],
    ),
    child: SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.neutral300,
            disabledForegroundColor: AppColors.neutral600,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Save Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}
