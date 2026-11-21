import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../features/legal/screens/legal_screen.dart';
import '../constants/app_colors.dart';
import 'kaya_popup.dart';

/// The box ticked before anything sensitive is sent: an ID and selfie, a
/// business document, a certificate or a license. The form keeps its send
/// button off until it is ticked, and the upload tells the server it was,
/// which records when and against which version of the Terms.
class ConsentCheck extends StatefulWidget {
  const ConsentCheck({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<ConsentCheck> createState() => _ConsentCheckState();
}

class _ConsentCheckState extends State<ConsentCheck> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => _open(0);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = () => _open(1);

  void _open(int tab) => showKayaPopup(context, tall: true, builder: (_) => LegalScreen(initialTab: tab));

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 13, color: AppColors.neutral700, height: 1.5);
    const link = TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600);

    return Semantics(
      checked: widget.value,
      child: InkWell(
        onTap: () => widget.onChanged(!widget.value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: widget.value ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: widget.value ? AppColors.primary : AppColors.neutral400),
                ),
                child: widget.value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: body,
                    children: [
                      const TextSpan(text: 'This is mine and it is true. I agree to the '),
                      TextSpan(text: 'Terms', style: link, recognizer: _terms),
                      const TextSpan(text: ' and the '),
                      TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
                      const TextSpan(text: '. A fake document gets the account banned for good.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
