import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/widgets/location_picker_field.dart';

/// Add Employer Location.
///
/// Pops with { label, location_id, latitude, longitude } — it used to return
/// the bare display string, so the caller had no id to persist and the
/// employer's coordinates never changed.
class AddEmployerLocationScreen extends StatefulWidget {
  final String? initialValue;
  const AddEmployerLocationScreen({super.key, this.initialValue});

  @override
  State<AddEmployerLocationScreen> createState() => _AddEmployerLocationScreenState();
}

class _AddEmployerLocationScreenState extends State<AddEmployerLocationScreen> {
  late final TextEditingController _locationController;
  bool _isSaveEnabled = false;

  /// The PSGC row behind the field, so the caller can persist location_id and
  /// coordinates rather than just a label.
  LocationModel? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.initialValue ?? '');
    _locationController.addListener(_updateSaveButton);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _updateSaveButton() {
    setState(() {
      // A real selection, not just text — typed text has no location_id, so
      // saving it would leave the employer's coordinates pointing elsewhere.
      _isSaveEnabled = _selectedLocation != null;
    });
  }

  void _save() {
    if (_selectedLocation == null) return;
    Navigator.pop(context, {
      'label': _selectedLocation!.displayName,
      'location_id': _selectedLocation!.id,
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
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
        title: const Text(
          'Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
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
                  
                  const Text(
                    'Where is your business located?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Workers will see your location when you post jobs. This helps them find opportunities near them.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral600,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Location picker, not free text.
                  LocationPickerField(
                    controller: _locationController,
                    labelText: 'City or Municipality',
                    hintText: 'Search your city or municipality',
                    // City level, like the rest of the employer side.
                    cityLevel: true,
                    selection: _selectedLocation,
                    onSelected: (location) => setState(() {
                      _selectedLocation = location;
                      _isSaveEnabled = true;
                    }),
                    onCleared: () => setState(() {
                      _selectedLocation = null;
                      _isSaveEnabled = false;
                    }),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your exact address will not be shared publicly. Only the city/municipality will be visible.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.neutral900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaveEnabled ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    disabledForegroundColor: AppColors.neutral600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
