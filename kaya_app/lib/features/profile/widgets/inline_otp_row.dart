import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    Confirming a phone number or an email address, without leaving the tab.

    These used to be two things in two places: an editable row on the Profile
    tab that held the value, and a card on Verification that pushed a whole
    screen to confirm it. So the same phone number appeared twice, and neither
    copy could do the other one's job - the row could not verify and the card
    could not accept a number, which is why the server answered "add a phone
    number to your account first" to somebody looking straight at a Verify
    button.

    One row, three states: enter the value, enter the code, done. Nothing
    navigates, because there is nothing here big enough to be a screen - it is
    a field and a six digit code.

    A government ID is deliberately not built this way. That one is two photos,
    a document type and a wait for a human, and it earns its own screen.

    Styled to match InlineEditRow exactly, because they sit in the same list
    and any difference between them reads as one of them being unfinished.
*/
class InlineOtpRow extends StatefulWidget {
  const InlineOtpRow({
    super.key,
    required this.label,
    required this.value,
    required this.verified,
    required this.onSaveValue,
    required this.onSendCode,
    required this.onVerifyCode,
    this.hint,
    this.keyboardType,
    this.validator,
    this.emptyLabel = 'Not set',
  });

  final String label;

  /// The stored number or address, if there is one.
  final String? value;

  final bool verified;

  /// Persists a changed value. Returns an error, or null on success.
  final Future<String?> Function(String value) onSaveValue;

  /// Asks the server to send a code. Returns an error, or null on success.
  final Future<String?> Function() onSendCode;

  /// Checks the code. Returns an error, or null when it was accepted.
  final Future<String?> Function(String code) onVerifyCode;

  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String value)? validator;
  final String emptyLabel;

  @override
  State<InlineOtpRow> createState() => _InlineOtpRowState();
}

enum _Stage { idle, editing, code }

class _InlineOtpRowState extends State<InlineOtpRow> {
  late final TextEditingController _value =
      TextEditingController(text: widget.value ?? '');
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();

  _Stage _stage = _Stage.idle;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void didUpdateWidget(InlineOtpRow old) {
    super.didUpdateWidget(old);
    // A value refreshed from the server while idle should show; doing it
    // mid-edit would overwrite what is being typed.
    if (_stage == _Stage.idle && widget.value != old.value) {
      _value.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    if (widget.verified) return;

    setState(() {
      _stage = _Stage.editing;
      _error = null;
      _notice = null;
      _value.text = widget.value ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _cancel() {
    setState(() {
      _stage = _Stage.idle;
      _error = null;
      _notice = null;
      _code.clear();
      _value.text = widget.value ?? '';
    });
    FocusScope.of(context).unfocus();
  }

  /*
      Save first, then send.

      The code goes to whatever is stored on the account, so sending before
      saving a changed number would text the old one - and the person would
      sit waiting for a code that arrived somewhere else.
  */
  Future<void> _sendCode() async {
    final next = _value.text.trim();

    if (next.isEmpty) {
      setState(() => _error = '${widget.label} is required.');
      return;
    }

    final invalid = widget.validator?.call(next);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    String? failure;
    if (next != (widget.value ?? '').trim()) {
      failure = await widget.onSaveValue(next);
    }
    failure ??= await widget.onSendCode();

    if (!mounted) return;

    setState(() {
      _busy = false;
      _error = failure;
      if (failure == null) {
        _stage = _Stage.code;
        _notice = 'Code sent. It is good for ten minutes.';
      }
    });

    if (failure == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();

    if (code.isEmpty) {
      setState(() => _error = 'Enter the code we sent.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await widget.onVerifyCode(code);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _error = failure;
      // Stays open on failure so a mistyped digit can be corrected.
      if (failure == null) {
        _stage = _Stage.idle;
        _code.clear();
        _notice = null;
      }
    });

    if (failure == null) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final filled = (widget.value ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _stage == _Stage.idle ? _open : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _error != null ? AppColors.error : AppColors.neutral200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: AppColors.neutral500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (_stage == _Stage.editing)
                            TextField(
                              controller: _value,
                              focusNode: _focus,
                              keyboardType: widget.keyboardType,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: widget.hint,
                              ),
                              style: const TextStyle(
                                  fontSize: 15, color: AppColors.neutral900),
                            )
                          else if (_stage == _Stage.code)
                            TextField(
                              controller: _code,
                              focusNode: _focus,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '6-digit code',
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                letterSpacing: 2,
                                color: AppColors.neutral900,
                              ),
                            )
                          else
                            Text(
                              filled ? widget.value!.trim() : widget.emptyLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: filled
                                    ? AppColors.neutral900
                                    : AppColors.neutral400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _trailing(),
                  ],
                ),
                if (_notice != null && _error == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _notice!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.neutral600),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailing() {
    if (widget.verified) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Verified',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ),
      );
    }

    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_stage == _Stage.idle) {
      return const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Text(
          'Verify',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Cancel',
              style: TextStyle(fontSize: 13, color: AppColors.neutral600)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: _stage == _Stage.editing ? _sendCode : _verify,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _stage == _Stage.editing ? 'Send code' : 'Confirm',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
