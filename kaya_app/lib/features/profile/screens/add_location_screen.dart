import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AddLocationScreen extends StatefulWidget {
  /// Pass the currently saved location string (e.g. "Poblacion, Urdaneta City")
  final String? initialValue;
  const AddLocationScreen({super.key, this.initialValue});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _barangayCtrl;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill: saved format is "Barangay, City"
    String city = '', barangay = '';
    if (widget.initialValue != null && widget.initialValue!.contains(',')) {
      final parts = widget.initialValue!.split(',');
      barangay = parts[0].trim();
      city = parts.sublist(1).join(',').trim();
    }
    _cityCtrl     = TextEditingController(text: city);
    _barangayCtrl = TextEditingController(text: barangay);
    _isSaveEnabled = city.isNotEmpty && barangay.isNotEmpty;

    _cityCtrl.addListener(_update);
    _barangayCtrl.addListener(_update);
  }

  void _update() {
    setState(() {
      _isSaveEnabled = _cityCtrl.text.trim().isNotEmpty && _barangayCtrl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _barangayCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final city     = _cityCtrl.text.trim();
    final barangay = _barangayCtrl.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('City / Municipality is required')));
      return;
    }
    if (barangay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barangay / District is required')));
      return;
    }
    Navigator.pop(context, '$barangay, $city');
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  const Text('Helps employers find workers in their area.',
                      style: TextStyle(fontSize: 15, color: AppColors.neutral600, height: 1.5)),
                  const SizedBox(height: 32),
                  _field(_cityCtrl, 'City / Municipality', 'Enter city', Icons.location_city),
                  const SizedBox(height: 16),
                  _field(_barangayCtrl, 'Barangay / District', 'Enter barangay', Icons.location_on),
                ],
              ),
            ),
          ),
          _saveBar(_isSaveEnabled, _save),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.neutral600),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.neutral300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

Widget _saveBar(bool enabled, VoidCallback onSave) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );
}
