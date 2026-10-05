import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../providers/credits_provider.dart';
import 'plan_comparison.dart';

/*
    Top-up, as one card: what it is, what it adds, and the packages.

    The checklist used to sit above the packages as its own section, so the
    reason to buy and the place to buy were two separate things on the
    screen. Here they are one card: a header that says whether this account
    has it, the Free and Top-up table, then the packages.

    Any package, once, and it never expires - that is the whole rule
    (User::hasToppedUp on the server), so the header says exactly that.
*/
class TopUpSection extends StatelessWidget {
  const TopUpSection({
    super.key,
    required this.packages,
    required this.rows,
    required this.hasToppedUp,
    required this.buying,
    required this.onBuy,
  });

  final List<CreditPackage> packages;
  final List<ComparisonRow> rows;
  final bool hasToppedUp;
  final bool buying;
  final void Function(CreditPackage package) onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: PlanComparison(rows: rows),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(
              hasToppedUp ? 'Add more ${Credits.plural}' : 'Choose a package',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: packages.isEmpty ? _noPackages() : _grid(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: AppColors.neutral500),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Top-ups are free while KAYA is in testing. No payment is taken.',
                    style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top-up',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasToppedUp
                      ? 'On your account. It never expires.'
                      : 'Buy any package once. It never expires.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          if (hasToppedUp)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Two across where they fit, one across on the narrowest phones.
  Widget _grid() {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final columns = constraints.maxWidth >= 240 ? 2 : 1;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in packages)
            SizedBox(width: width, child: _packageTile(p)),
        ],
      );
    });
  }

  Widget _packageTile(CreditPackage package) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Credits.icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${package.credits}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral900,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                Credits.plural,
                style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            package.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: buying ? null : () => onBuy(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('₱${package.amountPhp.toStringAsFixed(0)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noPackages() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Text(
        'No packages right now. You can still use your free monthly ${Credits.plural}.',
        style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
      ),
    );
  }
}
