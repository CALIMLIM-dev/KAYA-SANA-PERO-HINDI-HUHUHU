import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/auth_provider.dart';
import 'report_response_screen.dart';

/*
    Where your account stands, and the way to argue with it.

    Every strike with its statement of reasons: the rule, what was found,
    your own content that was reported, what it limits and until when, and
    when it stops counting. Each can be appealed once, within its window,
    and somebody other than the administrator who issued it decides.

    Also the one screen a suspended account can reach. Signing in to one
    returns a short session that opens this and Support and nothing else;
    [standingToken] carries it, in memory only, and leaving signs out.
*/
class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({super.key, this.standingToken});

  /// Set when signing in to a suspended account. See ApiClient.sessionOverride.
  final String? standingToken;

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _status;
  String? _error;

  bool get _suspendedMode => widget.standingToken != null;

  @override
  void initState() {
    super.initState();
    if (_suspendedMode) ApiClient.sessionOverride = widget.standingToken;
    _load();
  }

  @override
  void dispose() {
    if (_suspendedMode) ApiClient.sessionOverride = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/account/standing');
      if (!mounted) return;
      setState(() {
        _status = Map<String, dynamic>.from(res.data['data'] as Map);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _signOut() async {
    ApiClient.sessionOverride = null;
    final auth = context.read<AuthProvider>();
    final mode = context.read<AppModeProvider>();
    await auth.logout();
    await mode.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _appeal(Map<String, dynamic> strike) async {
    final sent = await showKayaPopup<bool>(
      context,
      builder: (_) => _AppealForm(strikeId: strike['id'] as int, rule: '${strike['rule']}'),
    );
    if (sent == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving a suspended session is signing out, never a way past it.
      canPop: !_suspendedMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _suspendedMode) _signOut();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: !_suspendedMode,
          title: const Text('Account Status', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: _status == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Try Again')),
                          ],
                        ),
                      ),
              )
            : RefreshIndicator(onRefresh: _load, child: _body(_status!)),
      ),
    );
  }

  Widget _body(Map<String, dynamic> s) {
    final strikes = (s['strikes'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final counting = (s['strikes_counting'] as num?)?.toInt() ?? 0;
    final paused = s['reports_paused_until'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StandingCard(status: s),
        const SizedBox(height: 12),
        Text(
          counting == 0
              ? 'No violations.'
              : '$counting ${counting == 1 ? 'violation' : 'violations'} on your account. Each one stops counting after ${s['strike_days']} days.',
          style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
        ),
        if (paused != null) ...[
          const SizedBox(height: 6),
          Text(
            'Your reporting is paused until ${formatModerationDate(paused)}.',
            style: const TextStyle(fontSize: 13, color: AppColors.neutral700),
          ),
        ],
        if (_suspendedMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => AppRouter.push(context, AppRouter.support),
                  child: const Text('Contact Support'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(onPressed: _signOut, child: const Text('Sign Out')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (strikes.isNotEmpty)
          const Text('Violation History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral700)),
        for (final strike in strikes) ...[
          const SizedBox(height: 8),
          _StrikeCard(strike: strike, onAppeal: () => _appeal(strike)),
        ],
      ],
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final until = status['suspended_until'] ?? status['restricted_until'];
    final (title, line) = switch (status['standing']) {
      'banned' => ('Banned', 'You can no longer use this account. You can still request a review or message Support.'),
      'suspended' => (
          until == null ? 'Suspended' : 'Suspended Until ${formatModerationDate(until, time: true)}',
          'You can only open this page and Support.',
        ),
      'restricted' => (
          'Limited Until ${formatModerationDate(until, time: true)}',
          'You cannot apply, post, or invite until then.',
        ),
      'under_review' => (
          'Under Review',
          'A serious report about you is being checked. Until then you cannot apply, post, or invite.',
        ),
      _ => ('Good Standing', 'Your account has no limits.'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
          const SizedBox(height: 4),
          Text(line, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral700)),
        ],
      ),
    );
  }
}

class _StrikeCard extends StatelessWidget {
  const _StrikeCard({required this.strike, required this.onAppeal});

  final Map<String, dynamic> strike;
  final VoidCallback onAppeal;

  @override
  Widget build(BuildContext context) {
    final appeal = strike['appeal'] is Map ? Map<String, dynamic>.from(strike['appeal'] as Map) : null;
    final content = strike['content'] is Map ? Map<String, dynamic>.from(strike['content'] as Map) : null;
    final counting = strike['counting'] == true;
    final endsAt = strike['ends_at'];
    final limits = const ['restriction', 'suspension', 'ban'].contains(strike['action']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${strike['action_label']}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.neutral900),
                ),
              ),
              Text(
                appeal?['status'] == 'overturned' ? 'Removed' : (counting ? 'Counting' : 'Expired'),
                style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line('Violation', '${strike['rule']}'),
          if ((strike['rule_description'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${strike['rule_description']}',
                  style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.neutral600)),
            ),
          _line('What We Found', '${strike['finding']}'),
          if (content != null) ...[
            const SizedBox(height: 4),
            ReportedContent(content: content),
            const SizedBox(height: 8),
          ],
          _line('Given', formatModerationDate(strike['issued_at'])),
          if (limits && endsAt != null) _line('Ends', formatModerationDate(endsAt, time: true)),
          if (counting) _line('Active Until', formatModerationDate(strike['expires_at'])),
          if (appeal != null) ...[
            const Divider(height: 20),
            _line(
              'Your Review Request',
              switch (appeal['status']) {
                'overturned' => 'Accepted. ${appeal['note'] ?? ''}',
                'upheld' => 'Not accepted. ${appeal['note'] ?? ''}',
                _ => 'Sent ${formatModerationDate(appeal['sent_at'])}. Waiting for a decision.',
              },
            ),
          ] else if (strike['can_appeal'] == true) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'You can request a review until ${formatModerationDate(strike['appeal_by'])}.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  ),
                ),
                OutlinedButton(onPressed: onAppeal, child: const Text('Request a Review')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
            Text(value, style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral900)),
          ],
        ),
      );
}

class _AppealForm extends StatefulWidget {
  const _AppealForm({required this.strikeId, required this.rule});

  final int strikeId;
  final String rule;

  @override
  State<_AppealForm> createState() => _AppealFormState();
}

class _AppealFormState extends State<_AppealForm> {
  final TextEditingController _text = TextEditingController();
  bool _sending = false;

  static const _min = 20;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ApiClient().post('/account/strikes/${widget.strikeId}/appeal', data: {'appeal': _text.text.trim()});
      if (!mounted) return;
      Navigator.pop(context, true);
      AppToast.success(context, 'Request sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Request a Review', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.rule, style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Why is this wrong?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending || _text.text.trim().length < _min ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Send Request'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
