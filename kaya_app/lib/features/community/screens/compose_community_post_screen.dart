import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verify_gate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/worker_profile_provider.dart';

/*
    Writing a notice.

    The kind of notice follows the account: a worker profile posts as a
    worker, a company posts as a business, and a hybrid picks. An
    individual employer has no notice to post - a person looking for one
    worker posts a job - so that side is not offered to them and the screen
    says where to go instead.

    The price is on screen before the button, the rule every spend in the
    app follows, and it comes from the server so an admin price change
    shows here without a release.
*/
class ComposeCommunityPostScreen extends StatefulWidget {
  const ComposeCommunityPostScreen({super.key});

  @override
  State<ComposeCommunityPostScreen> createState() => _ComposeCommunityPostScreenState();
}

class _ComposeCommunityPostScreenState extends State<ComposeCommunityPostScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// worker | employer | business. No category and no place: the board
  /// is a thread, and who is talking is the only thing a reader sorts by.
  String? _type;

  /// Up to four. One picture of one wall is the weakest version of this.
  static const int _maxPhotos = 4;
  final List<XFile> _photos = [];

  bool _posting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      setState(() {
        /*
            A company posts as a business. Everyone else posts as what
            they are, and a hybrid account defaults to worker - they can
            switch below, which is the one choice worth offering.
        */
        _type = auth.isCompanyEmployer
            ? 'business'
            : auth.workerProfileExists
                ? 'worker'
                : auth.employerProfileExists
                    ? 'employer'
                    : null;
      });
      context.read<CommunityProvider>().loadCosts();
      context.read<WorkerProfileProvider>().fetchCategories();
      context.read<CreditsProvider>().load();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _photos.add(picked));
    }
  }

  int? get _cost {
    final board = context.read<CommunityProvider>();
    return _type == 'business' ? board.businessCost : board.workerCost;
  }

  /// Whether this account holds the profile that kind of notice speaks for.
  bool _canPostAs(String kind) {
    final auth = context.read<AuthProvider>();

    return kind == 'worker'
        ? auth.workerProfileExists
        : auth.employerProfileExists;
  }

  Future<void> _submit() async {
    if (_posting || _type == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!await ensureVerified(context, action: 'post on the board')) return;
    if (!mounted) return;

    final credits = context.read<CreditsProvider>();
    final cost = _cost;
    if (cost != null && credits.hasLoadedOnce && credits.balance < cost) {
      await AppRouter.push(context, AppRouter.wallet);
      if (!mounted) return;
      await credits.refresh();
      return;
    }

    final board = context.read<CommunityProvider>();
    final days = board.days ?? 7;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Post this?'),
        content: Text(
          // Said before the charge, because the wait is the part people are
          // not expecting. The days start on approval, so nothing is lost
          // waiting, and a refusal returns the Barya.
          cost == null
              ? 'KAYA reads it first. Once approved it stays on the board for '
                  '$days days.'
              : 'KAYA reads it first. Once approved it stays on the board for '
                  '$days days — your days start then, and you get the Barya '
                  'back if it is not approved. No refund once it is up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(cost == null ? 'Post' : 'Post for $cost ${Credits.plural}'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _posting = true);
    final post = await board.create(
      type: _type!,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      photos: _photos,
    );
    if (!mounted) return;
    setState(() => _posting = false);

    if (post == null) {
      AppToast.error(context, board.error ?? 'Could not post.');
      return;
    }

    await credits.refresh();
    if (!mounted) return;
    AppToast.success(
      context,
      'Sent for review. It goes up once KAYA has read it, usually within a day.',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<CommunityProvider>();
    final cost = _type == 'business' ? board.businessCost : board.workerCost;
    final days = board.days ?? 7;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: const Text('New post', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _type == null
          ? _noSide()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  /*
                      Who you are posting as.

                      A company only ever posts as a business. Everyone else
                      picks, because a hybrid account genuinely is both and
                      the board sorts by exactly this.
                  */
                  if (!context.read<AuthProvider>().isCompanyEmployer) ...[
                    _label('Posting As'),
                    Row(
                      children: [
                        for (final kind in const [
                          ['worker', 'Worker'],
                          ['employer', 'Employer'],
                        ])
                          if (_canPostAs(kind[0]))
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(kind[1]),
                                selected: _type == kind[0],
                                onSelected: (_) => setState(() => _type = kind[0]),
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  _label('Title'),
                  TextFormField(
                    controller: _titleCtrl,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _input(_type == 'business'
                        ? 'Hiring five painters for two weeks'
                        : 'Mason available, weekdays'),
                    validator: (v) => (v ?? '').trim().length < 5 ? 'Give it a title.' : null,
                  ),
                  const SizedBox(height: 12),

                  _label('Details'),
                  TextFormField(
                    controller: _bodyCtrl,
                    maxLength: 500,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _input(_type == 'business'
                        ? 'The work, the dates, the pay, where to show up.'
                        : 'What you do, your rate, when you are free.'),
                    validator: (v) => (v ?? '').trim().length < 20 ? 'Say a little more.' : null,
                  ),
                  const SizedBox(height: 12),

                  _label('Photos'),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length +
                          (_photos.length < _maxPhotos ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (i == _photos.length) {
                          return GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.neutral300),
                              ),
                              child: const Center(
                                child: Icon(Icons.add_photo_alternate_outlined,
                                    color: AppColors.neutral500),
                              ),
                            ),
                          );
                        }

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 96,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(File(_photos[i].path), fit: BoxFit.cover),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton.filled(
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                        minimumSize: const Size(28, 28)),
                                    onPressed: () =>
                                        setState(() => _photos.removeAt(i)),
                                    icon: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    cost == null
                        ? 'On the board for $days days.'
                        : 'On the board for $days days, $cost ${Credits.plural}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _posting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: _posting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(cost == null ? 'Post' : 'Post for $cost ${Credits.plural}'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _noSide() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 40, color: AppColors.neutral400),
          const SizedBox(height: 12),
          const Text(
            'Looking for one worker? Post a job instead. The board is for workers saying they are free and for businesses that are hiring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.neutral600, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.postJob),
            child: const Text('Post a Job'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral700)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

