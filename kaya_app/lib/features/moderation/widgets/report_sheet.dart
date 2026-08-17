import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/// Reports another user.
///
/// This replaces a dialog that asked "are you sure?", showed "Report submitted.
/// Thank you." and sent nothing at all. Someone reporting harassment was told
/// it had been received while no report existed — worse than having no button,
/// because it stops them from telling anyone who could act.
///
/// Reasons are fetched from the server rather than listed here, so the app can
/// only send codes the moderation queue knows how to display.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.reportedId,
    required this.reportedName,
    this.subjectType,
    this.subjectId,
  });

  final int reportedId;
  final String reportedName;

  /// What the report is about, when it is not the account itself.
  final String? subjectType;
  final int? subjectId;

  static Future<void> show(
    BuildContext context, {
    required int reportedId,
    required String reportedName,
    String? subjectType,
    int? subjectId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        reportedId: reportedId,
        reportedName: reportedName,
        subjectType: subjectType,
        subjectId: subjectId,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final ApiClient _api = ApiClient();
  final TextEditingController _details = TextEditingController();

  List<Map<String, dynamic>> _reasons = const [];
  String? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final response = await _api.get('/report-reasons');
      final list = (response.data['data']['reasons'] as List)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _reasons = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the list of reasons. Check your connection.';
      });
    }
  }

  // "Something else" carries no meaning on its own, so it has to be explained.
  bool get _needsDetails => _selected == 'other';

  bool get _canSubmit =>
      _selected != null &&
      !_submitting &&
      (!_needsDetails || _details.text.trim().isNotEmpty);

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _api.post('/reports', data: {
        'reported_id': widget.reportedId,
        'reason_code': _selected,
        if (_details.text.trim().isNotEmpty) 'description': _details.text.trim(),
        if (widget.subjectType != null) 'subject_type': widget.subjectType,
        if (widget.subjectId != null) 'subject_id': widget.subjectId,
      });

      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Report sent. Our team will review it.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report ${widget.reportedName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only our team sees this. They will not be told who reported them.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_reasons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.neutral400),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load the list of reasons.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadReasons();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      children: [
        for (final reason in _reasons) _buildReason(reason),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _details,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _needsDetails
                  ? 'Tell us what happened'
                  : 'Add anything else that helps (optional)',
              hintStyle: TextStyle(fontSize: 13.5, color: AppColors.neutral400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.neutral300),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(fontSize: 13.5),
          ),
        ],
        if (_error != null && _reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildReason(Map<String, dynamic> reason) {
    final code = reason['code'] as String;
    final selected = _selected == code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selected = code),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? AppColors.error.withValues(alpha: 0.04) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.error : AppColors.neutral200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 19,
                color: selected ? AppColors.error : AppColors.neutral300,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason['label'] as String,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason['description'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neutral600,
                  side: BorderSide(color: AppColors.neutral300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.neutral300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
