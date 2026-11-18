import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../core/widgets/popup_form.dart';
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

/// Opens one top-up's receipt in a pop-up.
Future<void> showReceipt(BuildContext context, Map<String, dynamic> receipt, {bool justPaid = false}) =>
    showKayaPopup<void>(context, builder: (_) => ReceiptView(receipt: receipt, justPaid: justPaid));

/// One top-up's receipt.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.receipt, this.justPaid = false});

  final Map<String, dynamic> receipt;
  final bool justPaid;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final status = r['check_status'] as String?;
    final amount = (r['amount_php'] as num?)?.toDouble() ?? 0;

    return PopupForm(
      title: justPaid ? '${r['credits']} Barya Added' : 'Receipt',
      subtitle: justPaid ? 'We will check your payment against our GCash history.' : null,
      actionLabel: 'Done',
      showCancel: false,
      onAction: () => Navigator.pop(context),
      children: [
        _row('Receipt No.', '${r['receipt_no'] ?? ''}'),
        _row('Date', _date(r['paid_at'])),
        _row('Package', '${r['package'] ?? ''}'),
        _row('Barya', '${r['credits'] ?? ''}'),
        _row('Amount', '₱${amount.toStringAsFixed(2)}'),
        _row('Paid With', r['method'] == 'gcash' ? 'GCash' : 'Free Top-up'),
        if (r['gcash_ref'] != null) _row('GCash Ref No.', '${r['gcash_ref']}'),
        _row('Status', _status(status), color: _statusColor(status)),
      ],
    );
  }

  Widget _row(String label, String value, {Color color = AppColors.neutral900}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.neutral600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      );
}

/// Opens the list of every top-up; tapping one opens its receipt.
Future<void> showReceipts(BuildContext context) =>
    showKayaPopup<void>(context, tall: true, builder: (_) => const ReceiptsList());

class ReceiptsList extends StatefulWidget {
  const ReceiptsList({super.key});

  @override
  State<ReceiptsList> createState() => _ReceiptsListState();
}

class _ReceiptsListState extends State<ReceiptsList> {
  late Future<List<Map<String, dynamic>>?> _rows;

  @override
  void initState() {
    super.initState();
    _rows = context.read<CreditsProvider>().receipts();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text('Receipts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.neutral200),
        Expanded(
          child: ColoredBox(
            color: AppColors.background,
            child: FutureBuilder<List<Map<String, dynamic>>?>(
              future: _rows,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final rows = snap.data;
                if (rows == null) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() => _rows = context.read<CreditsProvider>().receipts()),
                      child: const Text('Could not load. Try Again'),
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return const Center(child: Text('No top-ups yet.', style: TextStyle(fontSize: 14, color: AppColors.neutral600)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final status = r['check_status'] as String?;
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => showReceipt(context, r),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.neutral200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${r['credits']} Barya · ₱${((r['amount_php'] as num?) ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                                    const SizedBox(height: 2),
                                    Text('${r['receipt_no']} · ${_date(r['paid_at'])}',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500)),
                                  ],
                                ),
                              ),
                              Text(_status(status),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _statusColor(status))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
