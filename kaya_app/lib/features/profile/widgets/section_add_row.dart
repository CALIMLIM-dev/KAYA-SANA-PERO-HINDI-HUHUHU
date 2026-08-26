import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    The way to add another one, kept small.

    This started as a full-width outlined card sitting under each list, which
    gave every section a second block the same size and weight as a real entry.
    Three sections meant three of them, and the screen read as a column of
    buttons with the actual content squeezed between them.

    An add action is not content. It is a small quiet line under the things it
    adds to, in the accent colour so it is still obviously tappable - the shape
    every list-with-an-add uses, because it stays out of the way until it is
    wanted.
*/
class SectionAddRow extends StatelessWidget {
  const SectionAddRow({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sits tight under the last entry rather than floating between two
      // sections, so it reads as belonging to the list above it.
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
