import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/credits_provider.dart';
import 'receipt_screen.dart';

/// Pays for a package with KAYA's GCash QR.
///
/// The QR stays on screen with the steps under it. After paying in GCash
/// the person types the reference number from the GCash receipt and adds a
/// screenshot of it; the Barya is added at once and the receipt opens. An
/// admin checks the payment against the GCash history afterwards.
class GcashPayScreen extends StatefulWidget {
  const GcashPayScreen({super.key, required this.package});

  final CreditPackage package;

  @override
  State<GcashPayScreen> createState() => _GcashPayScreenState();
}

class _GcashPayScreenState extends State<GcashPayScreen> {
  final _ref = TextEditingController();
  XFile? _proof;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ref.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  String get _digits => _ref.text.replaceAll(RegExp(r'\D'), '');
  bool get _canSend => !_sending && _digits.length >= 10 && _proof != null;

  Future<void> _pickProof() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked != null && mounted) setState(() => _proof = picked);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final credits = context.read<CreditsProvider>();
    final receipt = await credits.payWithGcash(widget.package.id, _digits, _proof!.path);
    if (!mounted) return;
    setState(() => _sending = false);

    if (receipt == null) {
      AppToast.error(context, credits.error ?? 'Could not send. Please try again.');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt, justPaid: true)));
  }

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();
    final amount = widget.package.amountPhp.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pay with GCash', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              children: [
                Text('${widget.package.credits} Barya', style: const TextStyle(fontSize: 14, color: AppColors.neutral600)),
                const SizedBox(height: 2),
                Text('₱$amount', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
                const SizedBox(height: 14),
                if (credits.gcashQrUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: credits.gcashQrUrl,
                    width: 230,
                    height: 230,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const SizedBox(width: 230, height: 230, child: Center(child: CircularProgressIndicator())),
                    errorWidget: (_, _, _) => const SizedBox(
                      width: 230,
                      height: 230,
                      child: Center(child: Text('The QR could not be loaded.', style: TextStyle(color: AppColors.neutral600))),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(credits.gcashName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _step('1', 'Scan this QR in GCash. On the same phone, take a screenshot of it and upload it in GCash Scan QR.'),
          _step('2', 'Pay exactly ₱$amount.'),
          _step('3', 'Enter the reference number from your GCash receipt and add a screenshot of the receipt.'),
          const SizedBox(height: 16),
          TextField(
            controller: _ref,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(24)],
            decoration: InputDecoration(
              labelText: 'GCash Reference Number',
              hintText: 'The long number on your GCash receipt',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pickProof,
            icon: Icon(_proof == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline),
            label: Text(_proof == null ? 'Add Receipt Screenshot' : 'Receipt Screenshot Added'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Entering a reference number you did not pay is fraud and leads to a permanent ban.',
            style: TextStyle(fontSize: 12.5, color: AppColors.neutral600, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _canSend ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Get My Barya', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.primary,
              child: Text(n, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.neutral800, height: 1.4))),
          ],
        ),
      );
}
