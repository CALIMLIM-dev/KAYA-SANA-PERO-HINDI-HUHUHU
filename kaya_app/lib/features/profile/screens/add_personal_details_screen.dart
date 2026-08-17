import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';

class AddPersonalDetailsScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialEmail;
  const AddPersonalDetailsScreen({super.key, this.initialPhone, this.initialEmail});

  @override
  State<AddPersonalDetailsScreen> createState() => _AddPersonalDetailsScreenState();
}

class _AddPersonalDetailsScreenState extends State<AddPersonalDetailsScreen> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
    _isSaveEnabled = _phoneCtrl.text.isNotEmpty && _emailCtrl.text.isNotEmpty;
    _phoneCtrl.addListener(_update);
    _emailCtrl.addListener(_update);
  }

  void _update() {
    setState(() {
      _isSaveEnabled = _phoneCtrl.text.trim().isNotEmpty && _emailCtrl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (phone.isEmpty) {
      AppToast.info(context, 'Phone number is required');
      return;
    }
    // PH validation: 09XXXXXXXXX, +639XXXXXXXXX, or 9XXXXXXXXX
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final isValidPH = (digits.length == 11 && digits.startsWith('09')) ||
                      (digits.length == 12 && digits.startsWith('639')) ||
                      (digits.length == 10 && digits.startsWith('9'));
    if (!isValidPH) {
      AppToast.info(context, 'Enter a valid PH number (e.g. 09171234567)');
      return;
    }
    if (email.isEmpty) {
      AppToast.info(context, 'Email is required');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      AppToast.info(context, 'Enter a valid email address');
      return;
    }
    Navigator.pop(context, {'phone': phone, 'email': email});
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
        title: const Text('Personal Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
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
                  const Text('Contact Information',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  const Text('Employers can reach you through these details.',
                      style: TextStyle(fontSize: 15, color: AppColors.neutral600, height: 1.5)),
                  const SizedBox(height: 32),
                  _field(_phoneCtrl, 'Phone Number', '09123456789', Icons.phone, TextInputType.phone),
                  const SizedBox(height: 16),
                  _field(_emailCtrl, 'Email Address', 'your.email@example.com', Icons.email, TextInputType.emailAddress),
                ],
              ),
            ),
          ),
          _saveBar(_isSaveEnabled, _save),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon, TextInputType type) {
    final isPhone = type == TextInputType.phone;
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLength: isPhone ? 13 : null,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
