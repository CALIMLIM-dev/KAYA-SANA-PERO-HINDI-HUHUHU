import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/resume_opener.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/worker_profile_provider.dart';

/*
    The worker's resume, on their own profile.

    Upload, replace, open and remove all existed on the server and in the
    provider, and the employer's applicant screen had a View resume button
    waiting for one. Nothing on the worker's side ever offered to upload it,
    so the button never appeared. This is that missing card.

    PDF or Word, up to 5 MB, the same limits the server enforces. Employers
    only see it once the worker has applied to them.
*/
class ResumeCard extends StatefulWidget {
  const ResumeCard({super.key});

  @override
  State<ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<ResumeCard> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final size = result!.files.single.size;
    if (size > 5 * 1024 * 1024) {
      AppToast.error(context, 'That file is over 5 MB.');
      return;
    }

    setState(() => _busy = true);
    final provider = context.read<WorkerProfileProvider>();
    final ok = await provider.uploadResume(path);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      AppToast.success(context, 'Resume uploaded.');
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Could not upload the resume.');
    }
  }

  Future<void> _open() async {
    final myId = context.read<AuthProvider>().user?['id'] as int?;
    if (myId == null) return;

    setState(() => _busy = true);
    final failure = await ResumeOpener.open(myId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) AppToast.error(context, failure);
  }

  Future<void> _remove() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove resume?'),
        content: const Text('Employers you apply to will no longer be able to open it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<WorkerProfileProvider>();
    final ok = await provider.deleteResume();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) AppToast.error(context, provider.errorMessage ?? 'Could not remove the resume.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WorkerProfileProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Resume',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.neutral900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            p.hasResume
                ? 'Employers you apply to can open it.'
                : 'PDF or Word, up to 5 MB. Employers you apply to can open it.',
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral600),
          ),
          const SizedBox(height: 10),
          if (p.hasResume) ...[
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.neutral500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.resumeFileName ?? 'Resume',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.neutral800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (p.resumeUploadedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  'Uploaded ${_date(p.resumeUploadedAt!)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _button('Open', Icons.open_in_new, _busy ? null : _open),
                _button('Replace', Icons.upload_file_outlined, _busy ? null : _pickAndUpload),
                _button('Remove', Icons.delete_outline, _busy ? null : _remove, danger: true),
              ],
            ),
          ] else
            _button('Upload resume', Icons.upload_file_outlined, _busy ? null : _pickAndUpload),
        ],
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? onTap, {bool danger = false}) {
    final color = danger ? AppColors.error : AppColors.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 13, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
