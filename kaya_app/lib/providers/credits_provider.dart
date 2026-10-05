import 'package:flutter/foundation.dart';

import '../data/services/api_client.dart';

/// One top-up option, priced by the server.
class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.amountPhp,
  });

  final int id;
  final String name;
  final int credits;
  final double amountPhp;

  /// What one credit works out at, for the "cheaper per credit" line.
  double get perCredit => credits == 0 ? 0 : amountPhp / credits;

  factory CreditPackage.fromJson(Map<String, dynamic> json) => CreditPackage(
        id: (json['id'] as num).toInt(),
        name: '${json['name'] ?? ''}',
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        amountPhp: (json['amount_php'] as num?)?.toDouble() ?? 0,
      );
}

/// One line of the ledger, as the history screen shows it.
class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    required this.isRefund,
    this.note,
    this.createdAt,
  });

  final int id;
  final int delta;
  final int balanceAfter;
  final String reason;
  final bool isRefund;
  final String? note;
  final DateTime? createdAt;

  bool get isCredit => delta > 0;

  factory CreditEntry.fromJson(Map<String, dynamic> json) => CreditEntry(
        id: (json['id'] as num).toInt(),
        delta: (json['delta'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
        reason: '${json['reason'] ?? ''}',
        isRefund: json['is_refund'] == true,
        note: json['note'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}

/// The wallet.
///
/// The balance is never guessed here. Nothing decrements it optimistically:
/// the server is the only thing that knows what it is, and a number that is
/// wrong by one is worse than a number that arrives a moment late — this is
/// the one figure in the app people will check against their own arithmetic.
/// One line of the Free vs Top-up checklist.
class ComparisonRow {
  const ComparisonRow({
    required this.label,
    required this.free,
    required this.toppedUp,
  });

  final String label;
  final bool free;
  final bool toppedUp;
}

class CreditsProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  int _balance = 0;
  Map<String, int> _costs = const {};
  int _monthlyGrant = 0;
  int _claimableWelcome = 0;
  int _claimableMonthly = 0;
  bool _claimNeedsVerification = false;
  List<CreditPackage> _packages = const [];

  /*
      Free vs Top-up, as the server words it.

      Rows, not numbers: every price in a label is read from config on the
      server, so a price change moves the checklist without a build.
  */
  bool _hasToppedUp = false;
  List<ComparisonRow> _comparison = const [];

  bool get hasToppedUp => _hasToppedUp;
  List<ComparisonRow> get comparison => _comparison;

  @visibleForTesting
  void seedComparison(List<ComparisonRow> rows, {bool hasToppedUp = false}) {
    _comparison = rows;
    _hasToppedUp = hasToppedUp;
    _hasLoadedOnce = true;
    notifyListeners();
  }

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  List<CreditEntry> _entries = const [];
  bool _isHistoryLoading = false;

  int get balance => _balance;
  List<CreditPackage> get packages => _packages;
  List<CreditEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get error => _error;
  int get monthlyGrant => _monthlyGrant;

  /*
      The two free gifts, held apart.

      A welcome and this month's are different things, so they are offered
      separately and claimed separately — one tap, one gift, one line of
      history. Collecting both from a single button wrote two rows for one
      action, which reads as a bug to anyone who scrolls down and counts.
  */
  int get claimableWelcome => _claimableWelcome;
  int get claimableMonthly => _claimableMonthly;

  int get claimable => _claimableWelcome + _claimableMonthly;
  bool get hasSomethingToClaim => claimable > 0;

  /*
      The gift is waiting, but this account cannot collect it yet.

      Free barya to an unverified account is free barya to an email address,
      so the server holds the payout until identity is approved. The amount is
      still reported, deliberately — telling somebody they have nothing when
      twenty is sitting there would be untrue, and the gift is the strongest
      reason anyone has to finish verifying.

      Read from the server rather than from the auth profile's is_verified, so
      the app is not re-deriving a money rule the server owns.
  */
  bool get claimNeedsVerification => _claimNeedsVerification;

  /// What an action costs, or null while the wallet has not loaded.
  ///
  /// Read from the server rather than written into the app, so a price change
  /// does not need a new build to take effect.
  int? costOf(String action) => _costs[action];

  /// What a boost costs and how long it runs, from the server. Null until
  /// the wallet has loaded.
  int? get boostCost => _costs['boost'];
  int? get boostDays => _costs['boost_days'];

  /// Days a post is listed for before it costs anything. Editable from the
  /// admin panel, so it is read rather than compiled in.
  int? get freePostDays => _costs['post_free_days'];

  /*
      Pulls the balance back from the server after something spent from it.

      Separate from adopt() on purpose: adopt takes a number a response
      already carried, and this is for the paths whose response carries none.
      Both exist because load() will not do it - it returns early once it has
      run, so every call after the first was a no-op and the balance on screen
      went stale until something happened to force a refresh.

      That something was the wallet screen, which is why the only way to see a
      true balance was to walk to the wallet and come back. A spend now pulls
      it here instead, wherever the spend happened.
  */
  Future<void> afterSpending() => refresh();

  /// Fills the price table for a test, which has no server to fetch from.
  @visibleForTesting
  void seedCosts(Map<String, int> costs) {
    _costs = Map.of(costs);
    notifyListeners();
  }

  /*
      What a post costs for a span of days, before it is posted.

      The same arithmetic as JobDurationService::costForSpan on the server,
      from the two numbers it sends with the balance: the free days, and
      how many paid days one barya buys. Null until the wallet has loaded,
      so the screen can say nothing rather than guess a price.
  */
  int? postCostFor(int days) {
    final free = _costs['post_free_days'];
    final perBarya = _costs['post_days_per_barya'];
    if (free == null || perBarya == null || perBarya <= 0) return null;

    final paid = days - free;
    return paid <= 0 ? 0 : (paid / perBarya).ceil();
  }

  bool canAfford(String action) {
    final cost = _costs[action];
    return cost == null || _balance >= cost;
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoadedOnce && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/credits/wallet');
      final data = response.data['data'] as Map<String, dynamic>;

      _balance = (data['balance'] as num?)?.toInt() ?? 0;
      _monthlyGrant = (data['monthly_grant'] as num?)?.toInt() ?? 0;
      _claimNeedsVerification =
          data['claim_requires_verification'] == true;

      _adoptClaimable(data['claimable']);

      final costs = (data['costs'] as Map?) ?? const {};
      _costs = {
        for (final entry in costs.entries)
          '${entry.key}': (entry.value as num?)?.toInt() ?? 0,
      };

      _hasToppedUp = data['has_topped_up'] == true;
      _comparison = ((data['comparison'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => ComparisonRow(
                label: '${r['label'] ?? ''}',
                free: r['free'] == true,
                toppedUp: r['topped_up'] == true,
              ))
          .where((r) => r.label.isNotEmpty)
          .toList();

      _packages = ((data['packages'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => CreditPackage.fromJson(Map<String, dynamic>.from(p)))
          .toList();

      _hasLoadedOnce = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[credits] wallet load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  /// Lines fetched for the wallet history, the server's maximum page.
  static const int historyPageSize = 50;

  @visibleForTesting
  void seedHistory(List<CreditEntry> entries) {
    _entries = entries;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _isHistoryLoading = true;
    notifyListeners();

    try {
      final response = await _api.get('/credits/transactions',
          queryParameters: {'per_page': historyPageSize});
      final payload = response.data['data'];
      final rows = payload is Map ? payload['data'] : payload;

      _entries = ((rows as List?) ?? const [])
          .whereType<Map>()
          .map((r) => CreditEntry.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[credits] history failed: $e');
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  /// Tops up a package and returns the server's message, or null on failure.
  ///
  /// Free while the app is in testing: the server credits the package at
  /// once, and the account counts as topped up from then on. The balance is
  /// refetched rather than changed locally.
  Future<String?> topUp(int packageId) async {
    try {
      final response = await _api.post('/credits/checkout', data: {
        'package_id': packageId,
      });

      await load(force: true);
      return response.data['message'] as String? ?? 'Top-up added.';
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /*
      Collects whatever is owed.

      Returns how many were actually paid, which is not always what was on
      offer — two taps arriving together means the second one gets nothing, and
      saying so is better than celebrating credits that never arrived.
  */
  Future<int> claim(String type) async {
    try {
      final response = await _api.post('/credits/claim', data: {'type': type});
      final data = response.data['data'] as Map<String, dynamic>;

      _balance = (data['balance'] as num?)?.toInt() ?? _balance;

      // What is still owed comes back with the answer, so the card can drop
      // the gift just taken without guessing which one that was.
      _adoptClaimable(data['claimable']);
      notifyListeners();

      return ((data['claimed'] as Map?)?['total'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return 0;
    }
  }

  void _adoptClaimable(dynamic raw) {
    final claimable = (raw as Map?) ?? const {};
    _claimableWelcome = (claimable['welcome'] as num?)?.toInt() ?? 0;
    _claimableMonthly = (claimable['monthly'] as num?)?.toInt() ?? 0;
  }

  /*
      Puts a balance on the provider, for a test with no server to fetch one.

      This was adopt(), and it was written for something else: taking a
      balance a spend response had carried so the number could be corrected
      without another request. No endpoint ever returned one and nothing in
      the app ever called it - its only caller in the whole repository is the
      logout test, which needs a balance to prove clear() wipes it.

      So it is named for what it actually does. The staleness it was meant
      for is handled by afterSpending() above.
  */
  @visibleForTesting
  void seedBalance(int balance) {
    _balance = balance;
    notifyListeners();
  }

  /*
      adopt() was here.

      It took a balance a response had carried alongside something else, so a
      spend could correct the number without a second request. Nothing ever
      called it - not once, in the whole app - and the staleness it was
      written for is handled by afterSpending() above, which refetches at the
      point of the spend.

      Removed rather than left waiting for a caller. If the spending
      endpoints are ever changed to return the new balance, this is three
      lines to bring back.
  */

  void clear() {
    _balance = 0;
    _costs = const {};
    _packages = const [];
    _hasToppedUp = false;
    _comparison = const [];
    _entries = const [];
    _claimableWelcome = 0;
    _claimableMonthly = 0;
    _claimNeedsVerification = false;
    _hasLoadedOnce = false;
    _error = null;
    notifyListeners();
  }
}
