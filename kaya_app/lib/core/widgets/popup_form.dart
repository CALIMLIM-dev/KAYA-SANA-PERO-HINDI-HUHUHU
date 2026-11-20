import 'package:flutter/material.dart';
import '../../core/widgets/loading.dart';

import '../constants/app_colors.dart';

/*
    The layout every form pop-up uses, taken from Report and Blocked
    Accounts: a title with a close button, a line under it, the fields, and
    two full-width buttons at the bottom. Open it with showKayaPopup.

    Forms that each drew their own title, text buttons and field borders
    looked like three different apps; this is the one look.
*/
class PopupForm extends StatelessWidget {
  const PopupForm({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
    this.danger = false,
    this.cancelLabel = 'Cancel',
    this.showCancel = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String actionLabel;

  /// Null keeps the button disabled until the form is filled in.
  final VoidCallback? onAction;
  final bool busy;

  /// Red, for something that cannot be taken back (Cancel Job, Send Report).
  final bool danger;
  final String cancelLabel;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600, height: 1.4)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral200),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.neutral200))),
            child: Row(
              children: [
                if (showCancel) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral600,
                        side: const BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: danger ? AppColors.error : AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.neutral300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: busy
                        ? const SmallSpinner.white()
                        : Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A field's label, above it, as Edit Profile has them.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
      );
}

/// Edit Profile's text field look: white, rounded, light border, blue when focused.
InputDecoration fieldDecoration({String? hint, IconData? icon}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: width));

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.neutral500, size: 20) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(AppColors.neutral300),
    enabledBorder: border(AppColors.neutral300),
    focusedBorder: border(AppColors.primary, 2),
  );
}
