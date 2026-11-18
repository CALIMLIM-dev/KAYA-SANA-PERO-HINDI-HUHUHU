import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_form.dart';
import '../../../providers/credits_provider.dart';

/// Pays for a package with KAYA's GCash QR, in a pop-up over the wallet.
///
/// The person pays in GCash, then types the reference number from the GCash
/// receipt and adds a screenshot of it. The Barya is added at once; the
/// pop-up closes with the receipt, and an admin checks the payment later.
class GcashPayForm extends StatefulWidget {
  const GcashPayForm({super.key, required this.package});

  final CreditPackage package;

  @override
  State<GcashPayForm> createState() => _GcashPayFormState();
}

class _GcashPayFormState extends State<GcashPayForm> {
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
  bool get _ready => _digits.length >= 10 && _proof != null;

  Future<void> _pickProof() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked != null && mounted) setState(() => _proof = picked);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final credits = context.read<CreditsProvider>();
    final receipt = await credits.payWithGcash(widget.package.id, _digits, _proof!.path);
    if (!mounted) return;

    if (receipt == null) {
      setState(() => _sending = false);
      AppToast.error(context, credits.error ?? 'Could not send. Please try again.');
      return;
    }
    Navigator.pop(context, receipt);
  }

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<CreditsProvider>();
    final amount = widget.package.amountPhp.toStringAsFixed(2);

    return PopupForm(
      title: 'Pay with GCash',
      subtitle: '${widget.package.credits} Barya for ₱$amount',
      actionLabel: 'Get My Barya',
      busy: _sending,
      onAction: _ready ? _send : null,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral300),
          ),
          child: Column(
            children: [
              if (credits.gcashQrUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: credits.gcashQrUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const SizedBox(width: 220, height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (_, _, _) => const SizedBox(
                    width: 220,
                    height: 220,
                    child: Center(child: Text('The QR could not be loaded.', style: TextStyle(fontSize: 13.5, color: AppColors.neutral600))),
                  ),
                ),
              const SizedBox(height: 8),
              Text(credits.gcashName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
              const SizedBox(height: 2),
              Text('Pay exactly ₱$amount', style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Paying on this phone? Take a screenshot of the QR and upload it in GCash Scan QR.',
          style: TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.4),
        ),
        const FieldLabel('GCash Reference Number', top: 16),
        TextField(
          controller: _ref,
          enabled: !_sending,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(24)],
          decoration: fieldDecoration(hint: 'From your GCash receipt', icon: Icons.tag),
        ),
        const FieldLabel('Receipt Screenshot', top: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _sending ? null : _pickProof,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: Row(
                children: [
                  Icon(_proof == null ? Icons.image_outlined : Icons.check_circle_outline,
                      size: 20, color: _proof == null ? AppColors.neutral500 : AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _proof == null ? 'Add Screenshot' : 'Screenshot Added',
                      style: TextStyle(fontSize: 14, color: _proof == null ? AppColors.neutral400 : AppColors.neutral900),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.neutral400),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Entering a reference number you did not pay leads to a permanent ban.',
          style: TextStyle(fontSize: 12.5, color: AppColors.neutral500, height: 1.4),
        ),
      ],
    );
  }
}
