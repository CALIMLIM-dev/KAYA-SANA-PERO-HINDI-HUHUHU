import 'package:flutter/material.dart';

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
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delete account',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900)),
          const SizedBox(height: 12),
          const Text(
            'This cannot be undone. Your profile, photos, documents, resume, '
            'saved jobs and notifications are removed. Open job posts are '
            'closed and their applicants refunded. Remaining barya is '
            'forfeited. Messages you sent stay in the other person\'s chat '
            'under the name Deleted account.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.neutral700),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you are hired on a job, or have hired someone, finish or '
            'cancel that job first.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.neutral700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _hidden,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Your password',
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
                  onPressed: _canSubmit ? _submit : null,
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
                      : const Text('Delete account'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
