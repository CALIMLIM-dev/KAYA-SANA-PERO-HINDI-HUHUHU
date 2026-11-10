import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_auth/smart_auth.dart';

import '../constants/app_colors.dart';

/*
    The six-digit code box, drawn once.

    Every code in the app arrives the same way — six digits, ten minutes, five
    guesses — so it is entered the same way everywhere: password reset, phone,
    email. Before this there were three, and the one on the profile was a
    borderless line of text that did not read as a field at all, which is how
    you end up with a "Send code" button and nothing that looks like anywhere
    to type the answer.

    One real TextField sits invisible behind the boxes and holds the whole
    code. Six separate controllers is the obvious way to build this and the
    wrong one: pasting a code from the SMS app fills only the first box, and
    Android's autofill has nothing to target.
*/
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocus = false,
    this.enabled = true,
    this.hasError = false,
    this.onCompleted,
    this.smsAutofill = false,
  });

  /// Where the code arrives by text on this same phone: Android asks once
  /// ("Allow KAYA to read this code?") and the boxes fill themselves. No
  /// SMS permission is ever granted to KAYA.
  final bool smsAutofill;

  final TextEditingController controller;
  final int length;
  final bool autofocus;
  final bool enabled;

  /// Paints the boxes in the error colour. The message itself belongs to the
  /// caller — this widget never invents one.
  final bool hasError;

  /// Fired when the last digit lands, so the caller can submit without the
  /// person reaching for a button.
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> with WidgetsBindingObserver {
  final FocusNode _focus = FocusNode();

  /// A code sitting on the clipboard, offered as "Paste 482917".
  String? _clip;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
    if (widget.smsAutofill && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _listenForSms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.smsAutofill) {
      SmartAuth.instance.removeUserConsentApiListener().ignore();
    }
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  // Back from Gmail with the code copied: offer it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      final match = RegExp('(?<!\\d)\\d{${widget.length}}(?!\\d)').firstMatch(text);
      if (!mounted) return;
      final code = match?.group(0);
      setState(() => _clip = code != null && code != widget.controller.text ? code : null);
    } catch (_) {
      // No clipboard on this platform: nothing to offer.
    }
  }

  Future<void> _listenForSms() async {
    final res = await SmartAuth.instance.getSmsWithUserConsentApi(
      matcher: '\\d{${widget.length}}',
    );
    final code = res.data?.code;
    if (!mounted || code == null || code.length != widget.length) return;
    widget.controller.text = code;
  }

  void _paste() {
    final code = _clip;
    if (code == null) return;
    widget.controller.text = code;
    setState(() => _clip = null);
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    final offerPaste = widget.enabled && clip != null && widget.controller.text != clip;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _boxes(context),
        if (offerPaste)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: Text('Paste $clip'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
    );
  }

  Widget _boxes(BuildContext context) {
    final code = widget.controller.text;

    return Semantics(
      label: '${widget.length}-digit code',
      textField: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final available = constraints.maxWidth - gap * (widget.length - 1);
          // Caps the box so six digits do not stretch into paddles on a tablet,
          // and floors it so they still fit a 320dp phone.
          final box = (available / widget.length).clamp(38.0, 56.0);
          final height = box * 1.18;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? () => _focus.requestFocus() : null,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(widget.length, (i) {
                    final filled = i < code.length;
                    // The caret box is the next empty one, and only while the
                    // field actually has focus.
                    final active = _focus.hasFocus && i == code.length;

                    return Container(
                      width: box,
                      height: height,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? Colors.white
                            : AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.hasError
                              ? AppColors.error
                              : active
                                  ? AppColors.primary
                                  : filled
                                      ? AppColors.neutral400
                                      : AppColors.neutral200,
                          width: active || widget.hasError ? 1.8 : 1.2,
                        ),
                      ),
                      child: Text(
                        filled ? code[i] : '',
                        style: TextStyle(
                          fontSize: box * 0.46,
                          fontWeight: FontWeight.w700,
                          color: widget.hasError
                              ? AppColors.error
                              : AppColors.neutral900,
                        ),
                      ),
                    );
                  }),
                ),

                // The field that actually holds the code. Invisible, but real:
                // it takes the keyboard, the paste menu and Android's SMS
                // autofill, none of which a row of painted boxes can.
                Positioned.fill(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                      height: 0.01,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
