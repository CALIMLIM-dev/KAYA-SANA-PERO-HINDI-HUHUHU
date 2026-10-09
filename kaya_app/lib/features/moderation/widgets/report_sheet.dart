import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Screenshots or photos, up to three. The panel asked for substantial
  /// supporting evidence; a picture of what happened is the most of it.
  final List<XFile> _photos = [];
  static const _maxPhotos = 3;
  static const _minDetails = 20;
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

  /*
      What happened, always.

      Only "something else" used to need words, so most reports reached the
      team as a category and nothing more. A reason code is not evidence.
  */
  bool get _detailsEnough => _details.text.trim().length >= _minDetails;

  bool get _canSubmit => _selected != null && !_submitting && _detailsEnough;

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _photos.add(picked));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final fields = <String, dynamic>{
        'reported_id': widget.reportedId,
        'reason_code': _selected,
        'description': _details.text.trim(),
        if (widget.subjectType != null) 'subject_type': widget.subjectType,
        if (widget.subjectId != null) 'subject_id': widget.subjectId,
      };

      await _api.post(
        '/reports',
        data: _photos.isEmpty
            ? fields
            : FormData.fromMap({
                ...fields,
                'photos': [
                  for (final p in _photos)
                    await MultipartFile.fromFile(p.path, filename: p.name),
                ],
              }, ListFormat.multiCompatible),
      );

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
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      children: [
        // One dropdown, and everything else on screen from the start.
        DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          hint: const Text('Choose a reason', style: TextStyle(fontSize: 13.5)),
          items: [
            for (final reason in _reasons)
              DropdownMenuItem(
                value: reason['code'] as String,
                child: Text(reason['label'] as String,
                    style: const TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (code) => setState(() => _selected = code),
          decoration: InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        ...[
          TextField(
            controller: _details,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Describe what happened: when, where, and what was said or done',
              helperText: _detailsEnough
                  ? null
                  : 'At least $_minDetails characters '
                      '(${_details.text.trim().length}/$_minDetails)',
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
          const SizedBox(height: 4),
          _buildPhotos(),
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

  /// Up to three photos, each removable, with an Add tile while there is room.
  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos or screenshots (optional, up to $_maxPhotos)',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_photos[i].path), width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.neutral900, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photos.length < _maxPhotos)
              InkWell(
                onTap: _addPhoto,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.neutral300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.neutral500),
                      SizedBox(height: 2),
                      Text('Add', style: TextStyle(fontSize: 11, color: AppColors.neutral500)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
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
