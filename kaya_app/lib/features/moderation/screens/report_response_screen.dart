import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/*
    A report about you, and your side of it.

    Opened from the "A report about your account" notification. Shows the
    reason and the day - never who filed it or what they wrote - and lets
    the person answer once, before a decision. The admin reads the answer
    beside the report.
*/
class ReportResponseScreen extends StatefulWidget {
  const ReportResponseScreen({super.key, required this.reportId});

  final int reportId;

  @override
  State<ReportResponseScreen> createState() => _ReportResponseScreenState();
}

class _ReportResponseScreenState extends State<ReportResponseScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _answer = TextEditingController();

  Map<String, dynamic>? _report;
  String? _error;
  bool _sending = false;

  static const _minAnswer = 10;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/reports/${widget.reportId}');
      if (!mounted) return;
      setState(() {
        _report = Map<String, dynamic>.from(res.data['data'] as Map);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await _api.post('/reports/${widget.reportId}/respond', data: {
        'response': _answer.text.trim(),
      });
      if (!mounted) return;
      AppToast.success(context, 'Thank you. Your side is with our team.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _day(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('A report about you', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _report == null
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
                          OutlinedButton(onPressed: _load, child: const Text('Try again')),
                        ],
                      ),
                    ),
            )
          : _body(_report!),
    );
  }

  Widget _body(Map<String, dynamic> report) {
    final canRespond = report['can_respond'] == true;
    final answered = (report['response'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reason', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
              const SizedBox(height: 2),
              Text(
                (report['reason'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900),
              ),
              const SizedBox(height: 10),
              Text(
                'Filed ${_day(report['filed_at'])}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Who filed it and what they wrote stay private. Our team decides '
                'using both sides.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.neutral600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (answered.isNotEmpty) ...[
          const Text('Your side', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Text(answered, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ] else if (canRespond) ...[
          const Text('Your side', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral700)),
          const SizedBox(height: 6),
          TextField(
            controller: _answer,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'What happened, as you saw it',
              helperText: 'You can send this once.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending || _answer.text.trim().length < _minAnswer ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send my side', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ] else
          const Text(
            'This report has already been decided.',
            style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
          ),
      ],
    );
  }
}
