import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    A worker's trade and skills, the same on their own profile and on the one
    employers see, so the two cannot drift.

    The trade is a tag every skill under it belongs to. Each skill is a row:
    its name, its level as three rising bars, and the level and years in
    words. A skill with neither shows only its name.
*/

/// The job category, as a tag.
class TradeTag extends StatelessWidget {
  const TradeTag(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
      ),
    );
  }
}

/// One skill: name, level bars, "Expert · 9 yrs", and an optional [trailing]
/// (the remove button on the worker's own profile).
class SkillLine extends StatelessWidget {
  const SkillLine({
    super.key,
    required this.name,
    this.proficiency,
    this.years,
    this.trailing,
  });

  final String name;
  final String? proficiency;
  final int? years;
  final Widget? trailing;

  static int levelOf(String? proficiency) => switch (proficiency?.toLowerCase()) {
        'beginner' => 1,
        'intermediate' => 2,
        'expert' || 'advanced' => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final p = (proficiency ?? '').trim();
    final level = levelOf(p);
    final detail = [
      if (p.isNotEmpty) p[0].toUpperCase() + p.substring(1).toLowerCase(),
      if (years != null && years! > 0) '$years yr${years == 1 ? '' : 's'}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.neutral900)),
          ),
          if (level > 0) ...[
            const SizedBox(width: 8),
            LevelMeter(level: level),
          ],
          if (detail.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(detail,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.neutral600,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A skill's level as three rising bars: one for beginner, two for
/// intermediate, three for expert. The word stays beside it.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 2.5),
          Container(
            width: 5,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(
              color: i <= level ? AppColors.primary : AppColors.neutral200,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// Skills as rows split by hairlines.
class SkillLines extends StatelessWidget {
  const SkillLines({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.neutral100),
          children[i],
        ],
      ],
    );
  }
}
