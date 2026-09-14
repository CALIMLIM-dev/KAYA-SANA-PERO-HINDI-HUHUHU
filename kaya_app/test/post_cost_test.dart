import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/providers/credits_provider.dart';

/*
    What a post costs, worked out on the phone.

    The same arithmetic as JobDurationService::costForSpan on the server,
    from the two numbers the wallet sends. If either side changes the rule
    and the other does not, the label on the button and the charge on the
    ledger disagree - so the numbers here are the ones the server test pins.
*/
void main() {
  CreditsProvider rule({int free = 7, int perBarya = 4}) => CreditsProvider()
    ..seedCosts({'post_free_days': free, 'post_days_per_barya': perBarya});

  test('a week is free', () {
    final c = rule();
    expect(c.postCostFor(1), 0);
    expect(c.postCostFor(7), 0);
  });

  test('every day past the week is priced, rounding up', () {
    final c = rule();
    expect(c.postCostFor(8), 1);
    expect(c.postCostFor(11), 1);
    expect(c.postCostFor(12), 2);
    expect(c.postCostFor(14), 2);
    expect(c.postCostFor(30), 6);
    expect(c.postCostFor(60), 14);
    expect(c.postCostFor(90), 21);
  });

  test('never goes down, and 61 is cheaper than 90', () {
    final c = rule();
    var last = 0;
    for (var d = 1; d <= 120; d++) {
      final cost = c.postCostFor(d)!;
      expect(cost, greaterThanOrEqualTo(last));
      last = cost;
    }
    expect(c.postCostFor(61)!, lessThan(c.postCostFor(90)!));
  });

  test('says nothing until the rule has arrived', () {
    expect(CreditsProvider().postCostFor(30), isNull);
  });

  test('follows the rule the server sends, not a built-in one', () {
    final c = rule(free: 3, perBarya: 2);
    expect(c.postCostFor(3), 0);
    expect(c.postCostFor(5), 1);
    expect(c.postCostFor(30), 14);
  });
}
