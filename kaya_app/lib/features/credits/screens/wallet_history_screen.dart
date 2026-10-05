import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/credits_provider.dart';
import '../widgets/wallet_history.dart';

/// Every Barya line, on its own screen.
///
/// It used to be the bottom of the wallet, under the top-up card, so reading
/// it meant scrolling past everything you could buy. The wallet now shows the
/// last few lines and opens this for the rest.
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CreditsProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: credits.loadHistory,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            WalletHistory(
              entries: credits.entries,
              loading: credits.isHistoryLoading,
            ),
          ],
        ),
      ),
    );
  }
}
