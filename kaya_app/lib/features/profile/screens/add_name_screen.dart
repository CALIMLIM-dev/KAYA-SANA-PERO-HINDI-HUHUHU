import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AddNameScreen extends StatefulWidget {
  final String? initialValue;
  const AddNameScreen({super.key, this.initialValue});

  @override
  State<AddNameScreen> createState() => _AddNameScreenState();
}

class _AddNameScreenState extends State<AddNameScreen> {
  late final TextEditingController _ctrl;
  bool _isSaveEnabled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
    _isSaveEnabled = _ctrl.text.trim().isNotEmpty;
    _ctrl.addListener(() {
      setState(() => _isSaveEnabled = _ctrl.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _ctrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name must be at least 2 characters')));
      return;
    }
    Navigator.pop(context, name);
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
          widget.initialValue != null ? 'Edit Name' : 'Add Your Name',
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
                  const Text('What\'s your full name?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  const Text('This will be visible to employers on your profile.',
                      style: TextStyle(fontSize: 15, color: AppColors.neutral600, height: 1.5)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.neutral300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontSize: 16, color: AppColors.neutral900),
                  ),
                ],
              ),
            ),
          ),
          _saveBar(_isSaveEnabled, _save),
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
