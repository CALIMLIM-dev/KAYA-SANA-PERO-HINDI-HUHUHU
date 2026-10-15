import 'package:flutter/material.dart';
import '../../../core/widgets/kaya_popup.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/end_session.dart';
import '../../../data/services/api_client.dart';

/*
    Deleting your account.

    Required by the Data Privacy Act, and the one thing in Settings that
    cannot be undone. The password is asked again so a phone left unlocked
    cannot end an account in two taps, and the sheet says plainly what goes
    before the button is enabled. The server refuses while a hire is under
    way and says so; that message is shown as it comes.
*/
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showKayaPopup(
    context,
    builder: (_) => const DeleteAccountSheet(),
  );
}

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _password = TextEditingController();
  final ApiClient _api = ApiClient();

  bool _understood = false;
  bool _submitting = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _understood && _password.text.isNotEmpty && !_submitting;

  /// One last, plain question before anything is deleted.
  Future<void> _confirmThenSubmit() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Your Account?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure == true && mounted) await _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _api.delete('/me', data: {'password': _password.text});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    // The server has already revoked the token; this clears the phone and
    // lands on the login screen, taking this sheet with it.
    await endSession(context);
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls: in a pop-up on a small phone at a large text size the whole
    // of it does not fit.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delete Account',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900)),
          const SizedBox(height: 12),
          for (final line in const [
            'Your profile, photos and documents will be deleted.',
            'Your open job posts will be closed.',
            'Your Barya will be lost.',
            'Finish or cancel any job you are hired on first.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 8),
                    child: Icon(Icons.circle, size: 5, color: AppColors.neutral500),
                  ),
                  Expanded(
                    child: Text(line,
                        style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral700)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _hidden,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Your Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_hidden ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I understand this cannot be undone',
                style: TextStyle(fontSize: 13.5)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!,
                style: const TextStyle(fontSize: 13, color: AppColors.error)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canSubmit ? _confirmThenSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Delete Account'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
