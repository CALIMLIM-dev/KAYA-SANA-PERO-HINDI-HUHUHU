import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/credits_provider.dart';

String _status(String? s) => switch (s) {
      'unchecked' => 'Being Checked',
      'received' => 'Confirmed',
      'not_received' => 'Not Received',
      _ => 'Paid',
    };

Color _statusColor(String? s) => switch (s) {
      'unchecked' => AppColors.pending,
      'not_received' => AppColors.error,
      _ => AppColors.success,
    };

String _date(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${months[d.month - 1]} ${d.day}, ${d.year} $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// One top-up's receipt.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.receipt, this.justPaid = false});

  final Map<String, dynamic> receipt;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final status = r['check_status'] as String?;
    final amount = (r['amount_php'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (justPaid) ...[
            const Icon(Icons.check_circle, size: 56, color: AppColors.success),
            const SizedBox(height: 8),
            Text('${r['credits']} Barya added',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            const SizedBox(height: 4),
            const Text('We will check your payment against our GCash history.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              children: [
                _row('Receipt No.', '${r['receipt_no'] ?? ''}'),
                _row('Date', _date(r['paid_at'])),
                _row('Package', '${r['package'] ?? ''}'),
                _row('Barya', '${r['credits'] ?? ''}'),
                _row('Amount', '₱${amount.toStringAsFixed(2)}'),
                _row('Paid With', r['method'] == 'gcash' ? 'GCash' : 'Free Top-up'),
                if (r['gcash_ref'] != null) _row('GCash Ref No.', '${r['gcash_ref']}'),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Status', style: TextStyle(fontSize: 14, color: AppColors.neutral600))),
                      Text(_status(status),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _statusColor(status))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.neutral600))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
            ),
          ],
        ),
      );
}

/// Every top-up, newest first; tap one for its receipt.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  late Future<List<Map<String, dynamic>>?> _rows;

  @override
  void initState() {
    super.initState();
    _rows = context.read<CreditsProvider>().receipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Receipts', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>?>(
        future: _rows,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data;
          if (rows == null) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _rows = context.read<CreditsProvider>().receipts()),
                child: const Text('Could not load your receipts. Try Again'),
              ),
            );
          }
          if (rows.isEmpty) {
            return const Center(child: Text('No top-ups yet.', style: TextStyle(color: AppColors.neutral600)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final status = r['check_status'] as String?;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.neutral200)),
                  title: Text('${r['credits']} Barya · ₱${((r['amount_php'] as num?) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${r['receipt_no']} · ${_date(r['paid_at'])}'),
                  trailing: Text(_status(status),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _statusColor(status))),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: r))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
