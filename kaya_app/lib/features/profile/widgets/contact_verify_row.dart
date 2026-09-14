import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    The phone and email rows on a profile.

    A summary and a way in — not the flow itself. The previous version tried
    to run the whole thing inside the row: tap to reveal a borderless line of
    text, a "Send code" link in the corner, then the same borderless line
    holding the code. Nothing in it read as a field, so it looked like a Send
    code button with nowhere to type the answer.

    Confirming a number is a real task with real failure states — a code that
    expires, five attempts, a provider that is not configured, a number that
    has to be saved before anything can be sent to it. That earns the screen
    it already has, and using it here means there is one code UI in the app
    instead of one per place a code is asked for.

    Styled to match InlineEditRow, because they sit in the same list and any
    difference between them reads as one of them being unfinished.
*/
class ContactVerifyRow extends StatelessWidget {
  const ContactVerifyRow({
    super.key,
    required this.label,
    required this.value,
    required this.verified,
    required this.onTap,
    this.emptyLabel = 'Not set',
  });

  final String label;

  /// The stored number or address, if there is one.
  final String? value;

  final bool verified;

  /// Opens the verification screen. The caller refreshes on return.
  final VoidCallback onTap;

  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final filled = (value ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // A verified number is settled; there is nothing left to do to it.
          onTap: verified ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: AppColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        filled ? value!.trim() : emptyLabel,
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
                if (verified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
