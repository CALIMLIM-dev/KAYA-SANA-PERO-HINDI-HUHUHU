import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/widgets/top_up_strip.dart';

/*
    Job Boost, on or off, with its price and its lock on it.

    It asked in a pop-up, added the price to the Post button and was dropped
    after posting for an account that had never topped up. What it takes is on
    the control now, before it is touched.
*/
class JobBoostToggle extends StatefulWidget {
  const JobBoostToggle({
    super.key,
    required this.on,
    required this.cost,
    required this.days,
    required this.onChanged,
    required this.onTopUp,
    this.blocked,
    this.paid = false,
  });

  final bool on;
  final int cost;
  final int days;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTopUp;

  /// Why it cannot be turned on, or null when it can.
  final String? blocked;

  /// Already boosted: turning it on costs nothing more.
  final bool paid;

  @override
  State<JobBoostToggle> createState() => _JobBoostToggleState();
}

class _JobBoostToggleState extends State<JobBoostToggle> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    // One that is on can always be turned off.
    final locked = widget.blocked != null && !widget.on;
    final ink = widget.on
        ? Colors.white
        : locked
            ? AppColors.neutral400
            : AppColors.neutral900;

    void tap() {
      setState(() => _tapped = locked);
      if (!locked) widget.onChanged(!widget.on);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          toggled: widget.on,
          label: 'Job Boost, ${Credits.amount(widget.cost)} for ${widget.days} days${locked ? ', locked' : ''}',
          excludeSemantics: true,
          onTap: tap,
          child: InkWell(
            key: const ValueKey('job-boost'),
            onTap: tap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: widget.on
                    ? AppColors.primary
                    : locked
                        ? AppColors.neutral100
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.on ? AppColors.primary : AppColors.neutral300),
              ),
              child: Row(
                children: [
                  Icon(locked ? Icons.lock_outline : Icons.flash_on, size: 18, color: ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Job Boost', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                        Text(
                          'Top of the job feed for ${widget.days} day${widget.days == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.on
                                ? Colors.white
                                : locked
                                    ? AppColors.neutral400
                                    : AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.paid ? 'Paid' : Credits.amount(widget.cost),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_tapped && locked) ...[
          const SizedBox(height: 8),
          TopUpStrip(reason: widget.blocked!, onTopUp: widget.onTopUp),
        ],
      ],
    );
  }
}
