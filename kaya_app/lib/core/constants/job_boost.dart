/*
    What a boost costs, mirrored from the server.

    The authority is `config/kaya.php` — the server charges from it and would
    refuse a request priced differently, so nothing here can overcharge anyone.
    These exist so the cost can be shown *before* the button is pressed, which
    is the rule applying and inviting already follow: no barya leaves a wallet
    without the number having been on screen first.

    Two constants rather than a fetch, deliberately. A price that arrives over
    the network is a price that is sometimes missing, and a confirmation dialog
    with a blank where the cost should be is worse than a stale figure. If these
    ever drift from the server the charge is still correct; only the label is
    wrong, and that is the safe direction for the error to fall.
*/
class JobBoost {
  const JobBoost._();

  /// Barya charged for one boost. Mirrors `kaya.credits.boost`.
  static const int cost = 8;

  /// How long the placement lasts. Mirrors `kaya.credits.boost_days`.
  static const int days = 3;
}
