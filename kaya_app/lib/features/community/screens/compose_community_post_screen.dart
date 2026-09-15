import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/credits.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/verify_gate.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';

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
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _type; // worker | business
  int? _categoryId;
  LocationModel? _place;
  XFile? _photo;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      setState(() {
        _type = auth.isCompanyEmployer
            ? 'business'
            : auth.workerProfileExists
                ? 'worker'
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
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  int? get _cost {
    final board = context.read<CommunityProvider>();
    return _type == 'business' ? board.businessCost : board.workerCost;
  }

  Future<void> _submit() async {
    if (_posting || _type == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!await ensureVerified(context, action: 'post on the board')) return;
    if (!mounted) return;

    final credits = context.read<CreditsProvider>();
    final cost = _cost;
    if (cost != null && credits.hasLoadedOnce && credits.balance < cost) {
      await Navigator.pushNamed(context, AppRouter.wallet);
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
          cost == null
              ? 'Your post stays on the board for $days days.'
              : 'Your post stays on the board for $days days. No refund once it is up.',
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
      categoryId: _categoryId,
      location: _place?.displayName ?? (_locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim()),
      locationId: _place?.id,
      photo: _photo,
    );
    if (!mounted) return;
    setState(() => _posting = false);

    if (post == null) {
      AppToast.error(context, board.error ?? 'Could not post.');
      return;
    }

    await credits.refresh();
    if (!mounted) return;
    AppToast.success(context, 'Posted. It stays up for $days days.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<CommunityProvider>();
    final categories = context.watch<WorkerProfileProvider>().categories;
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
                  // A company cannot hold a worker profile, so an account is
                  // ever one kind of poster; there is nothing to choose.
                  Text(
                    _type == 'business'
                        ? 'Posting as your business, to people looking for work.'
                        : 'Posting as a worker, to people who are hiring.',
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral600, height: 1.4),
                  ),
                  const SizedBox(height: 16),

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

                  _label('Category'),
                  DropdownButtonFormField<int?>(
                    initialValue: _categoryId,
                    decoration: _input('Pick one, or leave it'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Any')),
                      for (final c in categories)
                        DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 12),

                  _label('Where'),
                  LocationPickerField(
                    controller: _locationCtrl,
                    selection: _place,
                    labelText: '',
                    hintText: 'City or municipality',
                    requireSelection: false,
                    onSelected: (place) => setState(() => _place = place),
                    onCleared: () => setState(() => _place = null),
                  ),
                  const SizedBox(height: 12),

                  _label('Photo (optional)'),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _photo == null
                          ? const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.neutral500),
                                  SizedBox(width: 8),
                                  Text('Add a photo', style: TextStyle(color: AppColors.neutral600)),
                                ],
                              ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(File(_photo!.path), fit: BoxFit.cover),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IconButton.filled(
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    onPressed: () => setState(() => _photo = null),
                                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
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
            child: const Text('Post a job'),
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

