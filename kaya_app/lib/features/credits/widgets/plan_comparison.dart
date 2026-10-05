import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/credits_provider.dart';

/*
    Free and Top-up, side by side.

    A check or a cross per row, so somebody deciding whether to buy sees what
    it gets them. Everything in the job flow is a check on both sides on
    purpose - free gets the marketplace, a top-up gets promotion - and that
    is the honest shape of the product, so it is not hidden below the fold.

    Drawn as a pricing table: the Top-up column is one continuous band in the
    app's primary blue, so the eye reads down what a top-up adds. The labels
    come from the server with their prices already in them.
*/
class PlanComparison extends StatelessWidget {
  const PlanComparison({
    super.key,
    required this.rows,
  });

  final List<ComparisonRow> rows;

  static const double _freeWidth = 52;
  static const double _topUpWidth = 64;
  static const Radius _bandRadius = Radius.circular(12);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          label: const SizedBox.shrink(),
          free: _heading('Free', AppColors.neutral600),
          topUp: _heading('Top-up', Colors.white),
          topUpColor: AppColors.primary,
          topUpRadius: const BorderRadius.only(
              topLeft: _bandRadius, topRight: _bandRadius),
          verticalPadding: 9,
        ),
        for (var i = 0; i < rows.length; i++)
          _row(
            label: Text(
              rows[i].label,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: rows[i].free ? AppColors.neutral700 : AppColors.neutral900,
                fontWeight: rows[i].free ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            free: _mark(rows[i].free, AppColors.neutral500),
            topUp: _mark(rows[i].toppedUp, AppColors.primary),
            topUpColor: AppColors.primary.withValues(alpha: 0.07),
            topUpRadius: i == rows.length - 1
                ? const BorderRadius.only(
                    bottomLeft: _bandRadius, bottomRight: _bandRadius)
                : BorderRadius.zero,
            divider: i < rows.length - 1,
          ),
      ],
    );
  }

  /// One line of the table. The Top-up cell stretches to the row's height so
  /// the band runs unbroken from the heading to the last row.
  Widget _row({
    required Widget label,
    required Widget free,
    required Widget topUp,
    required Color topUpColor,
    required BorderRadius topUpRadius,
    double verticalPadding = 11,
    bool divider = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(0, verticalPadding, 10, verticalPadding),
              decoration: BoxDecoration(
                border: divider
                    ? const Border(bottom: BorderSide(color: AppColors.neutral200))
                    : null,
              ),
              alignment: Alignment.centerLeft,
              child: label,
            ),
          ),
          Container(
            width: _freeWidth,
            decoration: BoxDecoration(
              border: divider
                  ? const Border(bottom: BorderSide(color: AppColors.neutral200))
                  : null,
            ),
            alignment: Alignment.center,
            child: free,
          ),
          Container(
            width: _topUpWidth,
            decoration: BoxDecoration(color: topUpColor, borderRadius: topUpRadius),
            alignment: Alignment.center,
            child: topUp,
          ),
        ],
      ),
    );
  }

  Widget _heading(String text, Color color) => Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
      );

  Widget _mark(bool yes, Color color) => Icon(
        yes ? Icons.check : Icons.close,
        size: 18,
        color: yes ? color : AppColors.neutral400,
        semanticLabel: yes ? 'Included' : 'Not included',
      );
}
