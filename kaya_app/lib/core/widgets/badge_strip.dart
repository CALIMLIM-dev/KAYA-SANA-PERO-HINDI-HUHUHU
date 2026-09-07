import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'badge_medallion.dart';

/*
    The badges on a public profile.

    One widget for both sides of the marketplace, because a worker's badges and
    an employer's are the same thing said about different people — the server
    decides which apply and sends the same shape, so drawing them twice would
    only be two chances for the two to stop matching.

    Every badge arrives as {code, label, description}. The label is what shows;
    the description is the evidence behind it and appears on long press, so a
    claim like "Highly Rated" can be checked rather than taken on trust.

    Deliberately quiet. These are neutral chips with one icon, not coloured
    award ribbons — the identity ones already sit beside a verified tick
    elsewhere on the page, and a row of bright badges would compete with the
    rating and the work history, which carry more information.
*/
class BadgeStrip extends StatelessWidget {
  const BadgeStrip({super.key, required this.badges});

  /// Raw badge maps from the profile endpoint.
  final List<Map<String, dynamic>> badges;

  /// Nothing at all when there is nothing earned, rather than an empty box
  /// with a heading over it.
  bool get isEmpty => badges.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges.map((badge) {
        final code = (badge['code'] ?? '').toString();
        final label = (badge['label'] ?? '').toString();
        final description = (badge['description'] ?? '').toString();

        if (label.isEmpty) return const SizedBox.shrink();

        return Tooltip(
          message: description,
          triggerMode: TooltipTriggerMode.longPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The struck medal, not an outline icon: each badge has
                // its own glyph and its own metal, so a row of them
                // stops reading as one thing repeated.
                BadgeMedallion(code: code, size: 22),
                const SizedBox(width: 7),
                /*
                    Flexible, not fixed.

                    "Verified Business" beside "3 Years on KAYA" at text scale
                    1.3 on a 320dp phone is exactly the row that overflows, and
                    Wrap only breaks between chips, not inside one.
                */
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
