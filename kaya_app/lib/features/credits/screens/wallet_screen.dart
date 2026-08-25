import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/credits_provider.dart';

/// The wallet: what you have, what it costs, and how to get more.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CreditsProvider>().refresh();
      context.read<CreditsProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /*
      Paying happens in a browser, so the app hears nothing while it is gone.

      Credits are granted server side by the webhook, or by the reconciler if
      that never arrives — so coming back to the app is exactly when to ask
      again. No confirm call, no local balance change, nothing the client could
      lie about.
  */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<CreditsProvider>().refresh();
      context.read<CreditsProvider>().loadHistory();
    }
  }

  Future<void> _buy(CreditPackage package) async {
    if (_buying) return;
    setState(() => _buying = true);

    final credits = context.read<CreditsProvider>();
    final url = await credits.startTopUp(package.id);

    if (!mounted) return;
    setState(() => _buying = false);

    if (url == null) {
      AppToast.error(context, credits.error ?? 'Could not start the payment.');
      return;
    }

    final opened = await launchUrl(
      Uri.parse(url),
      // Externally on purpose: an in-app webview for a payment page is both a
      // worse experience and something people are right to distrust.
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!opened) {
      AppToast.error(context, 'Could not open the payment page.');
      return;
    }

    AppToast.info(context, 'Finish paying, then come back to this screen.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: Consumer<CreditsProvider>(
        builder: (context, credits, _) {
          if (credits.isLoading && !credits.hasLoadedOnce) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await credits.refresh();
              await credits.loadHistory();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _balanceCard(credits),
                const SizedBox(height: 22),
                _costsCard(credits),
                const SizedBox(height: 22),
                Text('Top up', style: _sectionStyle),
                const SizedBox(height: 4),
                Text(
                  'Cheaper per ${Credits.name} the more you buy.',
                  style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
                ),
                const SizedBox(height: 12),
                if (credits.packages.isEmpty)
                  _emptyPackages()
                else
                  ...credits.packages.map(_packageTile),
                const SizedBox(height: 26),
                Text('History', style: _sectionStyle),
                const SizedBox(height: 10),
                _history(credits),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _sectionStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral900,
  );

  Widget _balanceCard(CreditsProvider credits) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your balance',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Credits.icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Text(
                '${credits.balance}',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  Credits.plural,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          if (credits.monthlyGrant > 0) ...[
            const SizedBox(height: 12),
            Text(
              'You get ${credits.monthlyGrant} free every month.',
              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ],
      ),
    );
  }

  /// What things cost, read from the server rather than written into the app.
  Widget _costsCard(CreditsProvider credits) {
    final rows = <(String, String)>[
      ('Apply to a job', 'apply'),
      ('Invite a worker', 'invite'),
      ('Unlock contact details', 'unlock'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(rows[i].$1,
                        style: const TextStyle(fontSize: 14, color: AppColors.neutral800)),
                  ),
                  Icon(Credits.icon, size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    '${credits.costOf(rows[i].$2) ?? '—'}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _packageTile(CreditPackage package) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Credits.icon, color: AppColors.primary, size: 20),
        ),
        title: Row(
          children: [
            Text('${package.credits}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 5),
            Text(Credits.plural,
                style: const TextStyle(fontSize: 14, color: AppColors.neutral700)),
          ],
        ),
        subtitle: Text(
          '${package.name}  ·  ₱${package.perCredit.toStringAsFixed(2)} each',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
        ),
        trailing: ElevatedButton(
          onPressed: _buying ? null : () => _buy(package),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: Text('₱${package.amountPhp.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _emptyPackages() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Text(
        'Top up is not available yet. You can still use your free monthly '
        '${Credits.plural}.',
        style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
      ),
    );
  }

  Widget _history(CreditsProvider credits) {
    if (credits.isHistoryLoading && credits.entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (credits.entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: const Text(
          'Nothing yet. Applying to a job will show up here.',
          style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < credits.entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            _entryRow(credits.entries[i]),
          ],
        ],
      ),
    );
  }

  Widget _entryRow(CreditEntry entry) {
    final positive = entry.isCredit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Credits.describe(entry.reason, isRefund: entry.isRefund),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (entry.note != null) ...[
                  const SizedBox(height: 2),
                  Text(entry.note!,
                      style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
                ],
              ],
            ),
          ),
          Text(
            positive ? '+${entry.delta}' : '${entry.delta}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: positive ? AppColors.success : AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}
