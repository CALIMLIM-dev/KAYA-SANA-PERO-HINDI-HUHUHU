import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/*
    Verified, pending review, or not - the same chip on every card.

    The panel asked that verified and unverified accounts be told apart
    clearly. A check that only appeared for verified people could not do
    that: "not verified" looked the same as "did not load", and somebody
    whose ID was waiting on an admin looked the same as somebody who never
    sent one.

    The server says which in verification_state. A payload from before it
    existed still has is_verified, so that is the fallback.
*/
enum VerificationState {
  verified('Verified', Icons.verified, Color(0xFF2E7D32), AppColors.verified),
  verifiedBusiness('Verified business', Icons.verified, Color(0xFF2E7D32), AppColors.verified),
  pending('Pending review', Icons.schedule, Color(0xFF9A5B00), AppColors.pending),
  unverified('Not verified', Icons.info_outline, AppColors.neutral600, AppColors.unverified);

  const VerificationState(this.label, this.icon, this.text, this.tint);

  final String label;
  final IconData icon;

  /// Dark enough to read on the light tint behind it.
  final Color text;
  final Color tint;

  bool get isVerified => this == verified || this == verifiedBusiness;

  static VerificationState of(Map? person) {
    switch (person?['verification_state']) {
      case 'verified':
        return verified;
      case 'verified_business':
        return verifiedBusiness;
      case 'pending':
        return pending;
      case 'unverified':
        return unverified;
    }
    return person?['is_verified'] == true ? verified : unverified;
  }

  static VerificationState fromFlag(bool isVerified) =>
      isVerified ? verified : unverified;
}

class VerificationChip extends StatelessWidget {
  const VerificationChip({
    super.key,
    required this.state,
    this.size = 11,
    this.onDark = false,
  });

  final VerificationState state;

  /// Font size. The icon follows it.
  final double size;

  /// White on a coloured header, where the tinted chip would vanish.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : state.text;

    return Semantics(
      label: state.label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.55, vertical: size * 0.18),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withAlpha(46) : state.tint.withAlpha(30),
          borderRadius: BorderRadius.circular(size),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(state.icon, size: size * 1.15, color: fg),
            SizedBox(width: size * 0.3),
            Flexible(
              child: Text(
                state.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size, height: 1.2, color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The old two-state badge, kept for callers that only know a bool.
class VerificationBadgeWidget extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerificationBadgeWidget({
    super.key,
    required this.isVerified,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) => VerificationChip(
        state: VerificationState.fromFlag(isVerified),
        size: size * 0.75,
      );
}
