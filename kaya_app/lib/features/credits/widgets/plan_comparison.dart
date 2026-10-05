import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/credits_provider.dart';

/*
    Free and Top-up, side by side.

    A check or a cross per row, so somebody deciding whether to buy sees what
    it gets them. Everything in the job flow is a check on both sides on
    purpose - free gets the marketplace, a top-up gets promotion - and that
    is the honest shape of the product, so it is not hidden below the fold.

    The labels come from the server with their prices already in them. Plain
    on purpose: no highlight colour and no sales line, the same as the rest
    of the wallet.
*/
class PlanComparison extends StatelessWidget {
  const PlanComparison({
    super.key,
    required this.rows,
    required this.hasToppedUp,
  });

  final List<ComparisonRow> rows;
  final bool hasToppedUp;

  static const double _cell = 58;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              _heading('Free'),
              _heading('Top-up'),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.neutral100),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppColors.neutral700,
                      ),
                    ),
                  ),
                  _mark(rows[i].free),
                  _mark(rows[i].toppedUp),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 8, 8),
            child: Text(
              hasToppedUp
                  ? 'You have topped up, so everything in the Top-up column is yours. It does not expire.'
                  : 'Top-up means buying any package once. It does not expire.',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => SizedBox(
        width: _cell,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
      );

  Widget _mark(bool yes) => SizedBox(
        width: _cell,
        child: Icon(
          yes ? Icons.check : Icons.close,
          size: 18,
          color: yes ? AppColors.success : AppColors.neutral400,
          semanticLabel: yes ? 'Included' : 'Not included',
        ),
      );
}
