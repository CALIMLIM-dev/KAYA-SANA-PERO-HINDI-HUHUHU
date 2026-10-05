import 'package:flutter/material.dart';

/// What the currency is called and what it looks like.
///
/// The app's half of a pair — the server holds the same name in
/// `config/kaya.php`. Everything else in the codebase says "credit", so these
/// two places are the whole cost of renaming it.
///
/// "Barya" is Filipino for loose change. It is a placeholder, and it reads as
/// a token rather than as money, which is the position to hold: these are not
/// redeemable for cash and should never look like they are.
class Credits {
  const Credits._();

  static const String name = 'Barya';

  /// Filipino nouns do not inflect for number, so this is the same word. Kept
  /// as its own constant anyway, because an English placeholder would need
  /// both and nobody should have to hunt for the second one.
  static const String plural = 'Barya';

  /*
      Icons.toll rather than a coin or a peso sign.

      It reads as a countable token, which is exactly what these are. Anything
      that looks like currency invites the question of whether it can be
      cashed out, and the answer is no.
  */
  static const IconData icon = Icons.toll;

  /// The wallet itself, where the destination genuinely is a balance.
  static const IconData walletIcon = Icons.account_balance_wallet_outlined;

  /// "2 Barya", for a button that has to say the price before it is tapped.
  static String amount(int value) => '$value $plural';

  /// Plain words for a ledger reason, since the raw value is a database
  /// string and nobody outside the code should have to read one.
  static String describe(String reason, {bool isRefund = false}) {
    if (isRefund) return 'Refunded';

    return switch (reason) {
      'application' => 'Applied to a job',
      'invitation' => 'Invited a worker',
      'rehire_invite' => 'Invited a past worker',
      'unlock' => 'Unlocked contact details',
      'boost' => 'Boosted to the top',
      'job_duration' => 'Kept a job post up longer',
      'thread_ad' => 'Community board post',
      'topup' => 'Topped up',
      'monthly_grant' => 'Free monthly $plural',
      'launch_grant' => 'Welcome $plural',
      'badge_reward' => 'Badge reward',
      'refund' => 'Refunded',
      'admin_adjustment' => 'Adjusted by support',
      _ => 'Other',
    };
  }

  /// The icon beside a ledger line in the wallet history.
  static IconData iconFor(String reason, {bool isRefund = false}) {
    if (isRefund) return Icons.undo;

    return switch (reason) {
      'application' => Icons.send_outlined,
      'invitation' => Icons.mail_outline,
      'rehire_invite' => Icons.replay,
      'unlock' => Icons.lock_open_outlined,
      'boost' => Icons.trending_up,
      'job_duration' => Icons.schedule,
      'thread_ad' => Icons.campaign_outlined,
      'topup' => Icons.add_card_outlined,
      'monthly_grant' || 'launch_grant' => Icons.card_giftcard,
      'badge_reward' => Icons.military_tech_outlined,
      'refund' => Icons.undo,
      'admin_adjustment' => Icons.support_agent,
      _ => icon,
    };
  }
}
