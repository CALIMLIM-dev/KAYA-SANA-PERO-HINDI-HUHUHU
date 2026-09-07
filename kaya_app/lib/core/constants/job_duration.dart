/*
    How long a post stays up, and what more days cost.

    Mirrored from `config/kaya.php` for the same reason JobBoost is: the cost
    has to be on screen before the button is pressed, and a price that arrives
    over the network is a price that is sometimes missing. The server charges
    from its own config and would refuse a request priced differently, so
    nothing here can overcharge anyone - if these drift, the label is wrong and
    the charge is still right, which is the safe direction.
*/
class JobDuration {
  const JobDuration._();

  /// Days a new post gets for nothing. Mirrors `kaya.jobs.free_days`.
  static const int freeDays = 30;

  /// When the warning goes out. Mirrors `kaya.jobs.warn_days`.
  static const int warnDays = 7;

  /// The blocks that can be bought, cheapest per day last.
  /// Mirrors `kaya.credits.duration_14` and `duration_30`.
  static const List<({int days, int cost})> blocks = [
    (days: 14, cost: 3),
    (days: 30, cost: 5),
  ];
}
