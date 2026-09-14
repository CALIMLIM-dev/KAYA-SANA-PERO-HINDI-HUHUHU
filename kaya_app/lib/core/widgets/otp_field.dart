import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

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

class _OtpFieldState extends State<OtpField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
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
