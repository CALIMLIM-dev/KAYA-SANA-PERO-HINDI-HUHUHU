import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../data/services/api_client.dart';
import '../../applications/widgets/applicant_card.dart';

/*
    The worker's own card, as an employer's Applicants list shows it.

    A top-up opens a worker's card as a resume on the employer's list, and
    the worker never saw it: it only ever appeared on somebody else's phone,
    so what they had paid for was something they had to take on trust. This
    draws the very card the list draws, from the same fields, sent by the
    same helper on the server (ResumeBlock).

    Without a top-up it shows the card employers see now and, under it, the
    resume it would open as. Said plainly, not sold.
*/
class ResumePreviewScreen extends StatefulWidget {
  const ResumePreviewScreen({super.key});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _card;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/worker/profile/resume-preview');
      if (!mounted) return;
      setState(() {
        _card = (res.data['data'] as Map).cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// The card as the Applicants list would hold it: a pending application,
  /// nothing to accept or reject from here.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('What Employers See',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.neutral600)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : _body(),
    );
  }

  Widget _body() {
    final premium = _card!['is_premium'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _caption(premium
              ? 'Your card on an employer\'s Applicants list. You have topped up, so it opens as a resume.'
              : 'Your card on an employer\'s Applicants list, as it shows now.'),
          _cardAs(premium: premium),
          if (!premium) ...[
            const SizedBox(height: 12),
            _caption('After a top-up it opens as a resume, like this:'),
            _cardAs(premium: true),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => AppRouter.push(context, AppRouter.wallet),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                child: const Text('Go to Wallet'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // The rule, so nobody tops up expecting to be moved up the list.
          const Text(
            'Your place in the list is the same either way. Employers see '
            'applicants in order of fit to the job.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4, color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _caption(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13.5, height: 1.4, color: AppColors.neutral700),
        ),
      );
}
