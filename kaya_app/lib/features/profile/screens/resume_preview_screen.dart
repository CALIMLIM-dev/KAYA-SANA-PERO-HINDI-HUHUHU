import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/services/api_client.dart';
import '../../applications/widgets/applicant_card.dart';

/*
    The worker's own card, as an employer's Applicants list shows it, in a
    pop-up: the card the list draws, from the same fields the server sends
    (ResumeBlock). Without a top-up it shows the card now and the resume a
    top-up opens it as.
*/
class ResumePreviewPopup extends StatefulWidget {
  const ResumePreviewPopup({super.key});

  @override
  State<ResumePreviewPopup> createState() => _ResumePreviewPopupState();
}

class _ResumePreviewPopupState extends State<ResumePreviewPopup> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _card;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await _api.get('/worker/profile/resume-preview');
      if (!mounted) return;
      setState(() => _card = (res.data['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// The card as the Applicants list holds it: nothing to accept or reject here.
  Widget _cardAs({required bool premium}) => ApplicantCard(
        applicant: {
          ..._card!,
          'application_id': 0,
          'application_status': 'pending',
          'is_premium': premium,
        },
        showActions: false,
        perWorkerActions: false,
        onChanged: _load,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('What Employers See',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Flexible(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral600)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      );
    }
    if (_card == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final premium = _card!['is_premium'] == true;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        if (premium)
          _cardAs(premium: true)
        else ...[
          _label('Now'),
          _cardAs(premium: false),
          const SizedBox(height: 8),
          _label('With Top Up'),
          _cardAs(premium: true),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () {
              // The navigator first: this pop-up's context is gone once it closes.
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.pushNamed(AppRouter.wallet);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.neutral600)),
      );
}
