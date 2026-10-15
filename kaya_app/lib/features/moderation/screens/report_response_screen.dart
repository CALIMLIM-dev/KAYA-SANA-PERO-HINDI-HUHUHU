import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';
import '../widgets/evidence_photos.dart';

/*
    A report about you, and your side of it: fair notice.

    Opened from the "A report about your account" notification. Shows the
    rule and what it covers, the day, and your own content that was reported
    as it was at that moment - enough to answer it. Never who filed it, what
    they wrote, or the photos they sent. You answer once, with up to three
    photos of your own, and nothing is upheld before your time to answer
    runs out.
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
  final List<XFile> _photos = [];

  Map<String, dynamic>? _report;
  String? _error;
  bool _sending = false;

  static const _minAnswer = 10;

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
      final path = '/reports/${widget.reportId}/respond';
      final text = _answer.text.trim();
      if (_photos.isEmpty) {
        await _api.post(path, data: {'response': text});
      } else {
        await _api.postMultipart(
          path,
          FormData.fromMap({'response': text, 'photos': await EvidencePhotos.files(_photos)},
              ListFormat.multiCompatible),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('A Report About You', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          OutlinedButton(onPressed: _load, child: const Text('Try Again')),
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
    final outcome = report['outcome'] as String?;
    final rule = report['rule'] as String?;
    final content = report['content'] is Map ? Map<String, dynamic>.from(report['content'] as Map) : null;
    final photosSent = (report['photos_sent'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Reported For'),
              Text(
                (report['reason'] ?? '').toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900),
              ),
              if (rule != null) ...[
                const SizedBox(height: 4),
                Text(rule, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.neutral700)),
              ],
              const SizedBox(height: 10),
              Text(
                'Filed ${formatModerationDate(report['filed_at'])}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
              ),
            ],
          ),
        ),
        if (content != null) ...[
          const SizedBox(height: 12),
          _card(ReportedContent(content: content)),
        ],
        const SizedBox(height: 12),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Status'),
              Text(
                outcome ??
                    (canRespond
                        ? 'Nothing is decided before ${formatModerationDate(report['reply_by'], time: true)} unless you reply sooner.'
                        : 'Being reviewed.'),
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.neutral900),
              ),
              if (outcome != null && outcome != 'Closed with no action against you') ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => AppRouter.push(context, AppRouter.accountStatus),
                  child: const Text(
                    'See Account Status',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (answered.isNotEmpty) ...[
          _label('Your Side'),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(answered, style: const TextStyle(fontSize: 14, height: 1.4)),
              if (photosSent > 0) ...[
                const SizedBox(height: 8),
                Text(
                  photosSent == 1 ? '1 photo sent' : '$photosSent photos sent',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                ),
              ],
            ],
          )),
        ] else if (canRespond) ...[
          _label('Your Side'),
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
          EvidencePhotos(
            photos: _photos,
            label: 'Photos or screenshots (optional, up to ${EvidencePhotos.max})',
            onChanged: (photos) => setState(() => _photos
              ..clear()
              ..addAll(photos)),
          ),
          const SizedBox(height: 16),
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
                  : const Text('Send My Side', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Who filed it, what they wrote and any photos they sent stay private. '
          'Our team decides using both sides.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.neutral600),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: child,
      );
}

/// Your own content as it was when it was reported. Shared with Account status.
class ReportedContent extends StatelessWidget {
  const ReportedContent({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (final key in const ['title', 'name', 'company', 'location'])
        if ((content[key] ?? '').toString().isNotEmpty) content[key].toString(),
    ];
    final text = (content['text'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What was reported: ${(content['kind'] ?? 'Item').toString().toLowerCase()}',
          style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
        ),
        const SizedBox(height: 4),
        for (final line in lines)
          Text(line, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral800)),
        ],
        if (content['sent_at'] != null) ...[
          const SizedBox(height: 4),
          Text('Sent ${formatModerationDate(content['sent_at'], time: true)}',
              style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
        ],
      ],
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 14, 2026", or "Oct 14, 2026, 3:05 PM" with [time].
String formatModerationDate(Object? iso, {bool time = false}) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final day = '${_months[d.month - 1]} ${d.day}, ${d.year}';
  if (!time) return day;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$day, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}
