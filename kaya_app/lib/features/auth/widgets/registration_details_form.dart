import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/ph_phone_field.dart';

/*
    The details every new account gives: name, mobile, date of birth.

    The panel asked that the required registration details be mandatory.
    Sign-up used to ask for an email or a phone and a password, and the
    name came later if it came at all. Both doors - the email form and
    Google - use this one form, so neither is the short way round, and the
    server checks the same list (RegistrationRules).

    Middle name and suffix stay optional: many people have neither.
*/
class RegistrationDetailsForm extends StatefulWidget {
  const RegistrationDetailsForm({super.key});

  static const minAge = 18;

  @override
  State<RegistrationDetailsForm> createState() => RegistrationDetailsFormState();
}

class RegistrationDetailsFormState extends State<RegistrationDetailsForm> {
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _suffix = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _birthdate;

  String? _firstError, _lastError, _phoneError, _birthError;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _suffix, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The newest birthday that is old enough today.
  static DateTime latestAllowed(DateTime today) =>
      DateTime(today.year - RegistrationDetailsForm.minAge, today.month, today.day);

  /// Checks every field and shows what is wrong. Returns the payload for
  /// /register or /google-login, or null when something is missing.
  Map<String, dynamic>? collect() {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final phone = _phone.text.trim();
    final today = DateTime.now();

    setState(() {
      _firstError = first.isEmpty ? 'Enter your first name' : null;
      _lastError = last.isEmpty ? 'Enter your last name' : null;
      _phoneError = phone.isEmpty
          ? 'Enter your mobile number'
          : (isValidPHPhone(phone) ? null : 'Enter a valid PH number (e.g. 9171234567)');
      _birthError = _birthdate == null
          ? 'Enter your date of birth'
          : (_birthdate!.isAfter(latestAllowed(today))
              ? 'You must be ${RegistrationDetailsForm.minAge} or older to use KAYA.'
              : null);
    });

    if ([_firstError, _lastError, _phoneError, _birthError].any((e) => e != null)) {
      return null;
    }

    final b = _birthdate!;
    return {
      'first_name': first,
      if (_middle.text.trim().isNotEmpty) 'middle_name': _middle.text.trim(),
      'last_name': last,
      if (_suffix.text.trim().isNotEmpty) 'suffix': _suffix.text.trim(),
      'phone': toPHE164(phone),
      'birthdate': '${b.year.toString().padLeft(4, '0')}-'
          '${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
    };
  }

  /// Lets a test choose a date without driving the system picker.
  @visibleForTesting
  void setBirthdate(DateTime date) => setState(() {
        _birthdate = date;
        _birthError = null;
      });

  /// The person's name as typed, for the password check against it.
  String get typedName => '${_first.text.trim()} ${_last.text.trim()}'.trim();

  Future<void> _pickBirthdate() async {
    final today = DateTime.now();
    final last = latestAllowed(today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(last.year - 7, last.month, last.day),
      firstDate: DateTime(1900),
      // Nobody younger can be chosen, so the rule is never a surprise.
      lastDate: last,
      helpText: 'Date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthdate = picked;
        _birthError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('First name'),
        _text(_first, 'Juan', _firstError, () => _firstError = null, capitalize: true),
        const SizedBox(height: 14),
        _label('Middle name (optional)'),
        _text(_middle, 'Santos', null, () {}, capitalize: true),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Last name'),
                  _text(_last, 'Dela Cruz', _lastError, () => _lastError = null, capitalize: true),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Suffix (optional)'),
                  _text(_suffix, 'Jr.', null, () {}),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Mobile number'),
        PhPhoneField(
          controller: _phone,
          errorText: _phoneError,
          onChanged: (_) => setState(() => _phoneError = null),
        ),
        const SizedBox(height: 14),
        _label('Date of birth'),
        InkWell(
          onTap: _pickBirthdate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _deco(
              hint: 'Select your date of birth',
              icon: Icons.cake_outlined,
              errorText: _birthError,
            ),
            child: Text(
              _birthdate == null
                  ? 'Select your date of birth'
                  : '${_months[_birthdate!.month - 1]} ${_birthdate!.day}, ${_birthdate!.year}',
              style: TextStyle(
                fontSize: 15,
                color: _birthdate == null ? AppColors.neutral400 : AppColors.neutral900,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            'You must be ${RegistrationDetailsForm.minAge} or older. Only you and our team see this.',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
      );

  Widget _text(TextEditingController c, String hint, String? error, VoidCallback clear,
          {bool capitalize = false}) =>
      TextField(
        controller: c,
        textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
        onChanged: (_) => setState(clear),
        decoration: _deco(hint: hint, errorText: error),
      );

  InputDecoration _deco({required String hint, IconData? icon, String? errorText}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.neutral400),
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.neutral500),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.neutral50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
