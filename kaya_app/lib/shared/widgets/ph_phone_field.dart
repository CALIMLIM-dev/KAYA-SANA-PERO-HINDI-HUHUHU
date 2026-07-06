import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Philippine phone number input field.
/// - Shows +63 as a fixed prefix
/// - User types 10 digits (9XXXXXXXXX)
/// - If user types 0 first, it gets replaced with 9
/// - Limit: exactly 10 digits
/// - Valid PH mobile prefixes: 9XX (Globe, Smart, DITO, etc.)
class PhPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const PhPhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.suffix,
  });

  @override
  State<PhPhoneField> createState() => _PhPhoneFieldState();
}

class _PhPhoneFieldState extends State<PhPhoneField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      maxLength: 10,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _PHPhoneFormatter(),
      ],
      onChanged: (v) {
        widget.onChanged?.call(v);
      },
      decoration: InputDecoration(
        hintText: '9XXXXXXXXX',
        hintStyle: TextStyle(color: AppColors.neutral400),
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('+63', style: TextStyle(fontSize: 15, color: AppColors.neutral900, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: AppColors.neutral300),
            ],
          ),
        ),
        suffixIcon: widget.suffix,
        errorText: widget.errorText,
        filled: true,
        fillColor: AppColors.neutral50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// Replaces leading 0 with 9 automatically
class _PHPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    // If user starts with 0, replace with 9
    if (text.startsWith('0')) {
      text = '9${text.substring(1)}';
    }

    // Only digits, max 10
    text = text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.length > 10) text = text.substring(0, 10);

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Validates a PH phone number
/// Accepts what the user typed (10 digits starting with 9)
/// Valid mobile prefixes: 90x-99x (Globe, Smart, Sun, DITO, etc.)
bool isValidPHPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
  // After stripping, should be 10 digits starting with 9
  if (digits.length == 10 && digits.startsWith('9')) return true;
  // Also accept full format: 09XXXXXXXXX (11 digits) or +639XXXXXXXXX (12)
  if (digits.length == 11 && digits.startsWith('09')) return true;
  if (digits.length == 12 && digits.startsWith('639')) return true;
  return false;
}

/// Returns the full E.164 format: +639XXXXXXXXX
String toPHE164(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length == 10 && digits.startsWith('9')) return '+63$digits';
  if (digits.length == 11 && digits.startsWith('09')) return '+63${digits.substring(1)}';
  if (digits.length == 12 && digits.startsWith('639')) return '+$digits';
  return '+63$digits';
}
