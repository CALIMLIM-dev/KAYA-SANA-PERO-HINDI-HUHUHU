import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/*
    One row shape, used by both profile screens.

    Written after screenshotting the two screens side by side. They had grown
    apart: the worker profile put a 48x48 tinted icon square on the right of
    every row, the employer profile put one on the left, and between them they
    used five accent colours — blue, green, yellow — with no rule behind which
    got which. Ten of those stacked is a column of small logos, which is what
    reads as noise.

    Every row also carried a subtitle that restated its own title. "Full Name"
    over "Add your full name". "Skills" over "Add your skills". The second line
    is the first line with two more words, and it doubled the height of every
    row: four fitted on a screen where ten should.

    So: no icon box, no restated subtitle, and one widget rather than two
    implementations that can drift apart again.
*/

/// A single line of profile information.
///
/// Shows the label, and the value when there is one. When there is not, the
/// row says so quietly and offers the action — which is the same information
/// the old subtitle carried, in half the space.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.emptyHint,
    this.trailing,
    this.isLast = false,
  });

  final String label;

  /// What the user has filled in. Null or empty means not set yet.
  final String? value;

  /// Shown in place of the value when empty. Defaults to "Not set".
  ///
  /// Only worth passing when the label genuinely cannot carry the meaning —
  /// "Add your full name" under "Full Name" is not that case.
  final String? emptyHint;

  /// A badge or status pill. Rare on purpose.
  final Widget? trailing;

  final VoidCallback onTap;

  /// Suppresses the divider on the final row of a group.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final filled = (value ?? '').trim().isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            // 14 vertical rather than 16 all round: this lands a filled row at
            // about 64px and an empty one at 56, against roughly 130 before.
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          // The label recedes once there is a value, because
                          // the value is then the thing worth reading. On an
                          // empty row the label is all there is, so it leads.
                          fontWeight:
                              filled ? FontWeight.w500 : FontWeight.w600,
                          color: filled
                              ? AppColors.neutral600
                              : AppColors.neutral900,
                        ),
                      ),
                      if (filled) ...[
                        const SizedBox(height: 2),
                        Text(
                          value!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral900,
                          ),
                        ),
                      ] else if (emptyHint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          emptyHint!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.neutral500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
                const SizedBox(width: 4),
                Icon(
                  // Empty rows invite an action; filled rows are navigation.
                  filled ? Icons.chevron_right : Icons.add,
                  size: filled ? 22 : 20,
                  color: filled ? AppColors.neutral400 : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            // Inset to the text, not the card edge — a full-bleed rule cuts the
            // card in half instead of separating two rows inside it.
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, thickness: 1, color: AppColors.neutral100),
          ),
      ],
    );
  }
}

/// The white card that groups rows.
///
/// Rows live together in one card rather than each floating in its own, which
/// is what produced the stack of identical white slabs with 12px gutters.
class ProfileGroup extends StatelessWidget {
  const ProfileGroup({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.neutral500,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            // A hairline instead of an elevation shadow. Ten shadowed cards
            // stacked is what made the screen look upholstered.
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
