import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/constants/employer_type.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/utils/name_parts.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../profile/screens/onboarding_verification_screen.dart';
import '../../../core/widgets/app_toast.dart';

/// Employer onboarding flow.
///
/// Both employer types use the same router entry, but the setup steps branch:
/// - Company: type, company details, logo, government ID, business registration, finish.
/// - Individual: type, name/details, photo, government ID, finish.
class SetupEmployerProfileScreen extends StatefulWidget {
  const SetupEmployerProfileScreen({super.key});

  @override
  State<SetupEmployerProfileScreen> createState() =>
      _SetupEmployerProfileScreenState();
}

class _SetupEmployerProfileScreenState extends State<SetupEmployerProfileScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();

  /*
      Whether the account name may still be edited here.

      Verified - the server refuses the rename, so an editable field would
      only produce a rejection at the end of a long form.

      Already set - there is one name on an account and both profiles share
      it. Somebody setting up their second side could type a different one
      and silently rewrite the name on the profile they already had, which is
      how one account ended up presenting two. Same rule on the worker setup.
  */
  /*
      Answered by the server. This read `last_name`, which /me did not
      send - so the lock never came on and the second profile could be
      set up under a different name than the first.
  */
  bool get _nameIsLocked {
    final user = context.read<AuthProvider>().user;

    if (user?['name_locked'] == true) return true;
    if (user?['is_verified'] == true) return true;

    // A name already on the account is the same answer as the flag, and is
    // there even against a server that has not been updated yet.
    return ((user?['name'] as String?) ?? '').trim().isNotEmpty;
  }
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();

  EmployerType? _selectedType;

  /// Structured location chosen from the picker.
  LocationModel? _selectedLocation;

  int _currentStep = 0;
  bool _isSaving = false;

  /// Set when a document upload fails, so the end of the flow can say so.
  ///
  /// The profile itself still saves - verification is a separate record and
  /// can be retried - so this warns rather than aborting.
  bool _verificationUploadFailed = false;
  String? _tempImagePath; // Store image path in memory until Finish
  String _identityIdType = 'Philippine National ID';
  String? _identityIdPhotoPath;
  String? _identityIdPhotoName;
  String? _identitySelfiePath;
  String? _identitySelfieName;
  Map<String, dynamic>? _businessDocument;

  /// The type step is not shown to an account that already looks for
  /// work - it can only be an individual employer.
  bool get _skipsTypeStep =>
      context.read<AuthProvider>().workerProfileExists;

  /*
      A worker account has no choice to make on the type step, so it is not
      asked. It can only be an individual employer - a registered business
      does not also look for work - and showing the business option greyed
      out is still showing it. Individual is set and the flow opens on the
      details.
  */
  void _skipTypeStepIfWorker() {
    if (!mounted || _selectedType != null) return;
    if (!context.read<AuthProvider>().workerProfileExists) return;

    setState(() {
      _selectedType = EmployerType.individual;
      _currentStep = 1;
    });

    if (_pageController.hasClients) _pageController.jumpToPage(1);
  }

  /// Pages in the flow: type, details, photo, verification. Fixed - the
  /// type page is jumped over, not removed, so every index below stays put.
  static const int _pageCount = 4;

  /// What the user is counting: the type page is not one of them when it is
  /// never shown. Display only - never use this to decide where a page is.
  int get _totalSteps => _skipsTypeStep ? _pageCount - 1 : _pageCount;

  /// What to show in "Step x of y", which counts only the steps on screen.
  int get _stepNumber => _skipsTypeStep ? _currentStep : _currentStep + 1;

  bool get _isCompany => _selectedType == EmployerType.company;
  bool get _isLastStep => _currentStep == _pageCount - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final verificationProvider = context.read<VerificationProvider>();

      // Before the requests, so the step is never briefly on screen. The
      // router that opens this screen has already loaded the account.
      _skipTypeStepIfWorker();

      await auth.fetchMe();
      await verificationProvider.fetchVerifications(); // Fetch verification status
      if (!mounted) return;

      // And again once /me has answered, for a cold open that reached here
      // before the account was loaded.
      _skipTypeStepIfWorker();

      // Only prefill if the user hasn't started typing — these awaits take a
      // moment, and overwriting mid-typing made the entered name disappear.
      if (_firstNameController.text.isEmpty) {
        // The parts as sent; split from the composed name when they are not.
        final fallback = NameParts.of(auth.user?['name'] as String?);

        _firstNameController.text =
            auth.user?['first_name'] as String? ?? fallback.first ?? '';
        _middleNameController.text =
            auth.user?['middle_name'] as String? ?? fallback.middle ?? '';
        _lastNameController.text =
            auth.user?['last_name'] as String? ?? fallback.last ?? '';
        _suffixController.text =
            auth.user?['suffix'] as String? ?? fallback.suffix ?? '';
      }

      /*
          The location this account already gave on its other profile.

          Setting up the second side asked for it again, which is the
          duplication people notice - they are the same person standing in the
          same place. Prefilled with the PSGC id, not just the label, because
          a location saved without one has no coordinates and the account
          disappears from every distance calculation.

          Skipped once anything has been typed, same rule as the name above.
      */
      /*
          The city, not the barangay.

          A worker picks a barangay, and prefilling this side with it
          put the one value the employer picker refuses to offer into
          the employer's own field. /me resolves the same place
          upwards, so a hybrid gets their city here and their barangay
          on the worker profile.
      */
      final stored = auth.user?['known_location'] as Map<String, dynamic>?;
      final known =
          (stored?['city'] as Map<String, dynamic>?) ?? stored;

      if (known != null &&
          known['location_id'] != null &&
          _locationController.text.isEmpty) {
        final label = (known['label'] ?? '').toString();

        _locationController.text = label;
        _selectedLocation = LocationModel(
          id: (known['location_id'] as num).toInt(),
          name: label,
          displayName: label,
          type: 'city',
          latitude: (known['latitude'] as num?)?.toDouble(),
          longitude: (known['longitude'] as num?)?.toDouble(),
        );
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _companyNameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() async {
    // On an account that skips the type page, the details page is the first
    // one - going back from it leaves setup rather than revealing a step the
    // account is not asked.
    if (_currentStep == 0 || (_skipsTypeStep && _currentStep == 1)) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Profile Setup?'),
          content: const Text(
            'Your profile is not complete. If you leave now, all progress will be discarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Discard',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ) ?? false;
      
      if (shouldExit && mounted) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    _goToStep(_currentStep - 1);
  }

  Future<void> _handlePrimaryAction() async {
    if (_isLastStep) {
      // ONLY save on finish
      final saved = await _saveAllProfileData();
      if (!saved) return;
      
      final employerProvider = context.read<EmployerProfileProvider>();
      final completed = await employerProvider.completeSetup();
      if (!completed) {
        _showError(employerProvider.errorMessage ?? 'Failed to complete setup');
        return;
      }
      
      await _finishSetup();
      return;
    }

    if (_currentStep == 0) {
      if (_selectedType == null) return;
      _goToStep(1);
      return;
    }

    // For step 1 (details), just validate and move forward - DON'T save yet
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
      _goToStep(_currentStep + 1);
      return;
    }

    // All other steps: just navigate
    _goToStep(_currentStep + 1);
  }

  // NEW: Save everything at once on Finish
  Future<bool> _saveAllProfileData() async {
    // No need to validate again - we already validated at step 1
    if (_selectedType == null) return false;

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final employerProvider = context.read<EmployerProfileProvider>();
    final verificationProvider = context.read<VerificationProvider>();

    try {
      // Removed validation that blocks incomplete verification - now truly optional
      final hasCompleteIdentity =
          _identityIdPhotoPath != null && _identitySelfiePath != null;

      // 1. Save name if individual, and only when it is still theirs to
      // set. A locked name is already on the account; sending the fields
      // this screen no longer shows would clear the parts behind it.
      if (_selectedType == EmployerType.individual && !_nameIsLocked) {
        // The parts, same as worker setup. The server composes the display
        // name from them, so this screen never builds one.
        final nameSaved = await auth.updateMe(
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          suffix: _suffixController.text.trim(),
        );
        if (!nameSaved) {
          _showError(auth.errorMessage ?? 'Failed to save your name');
          return false;
        }
      }

      // 2. Create employer profile
      final success = await employerProvider.createProfile(
        employerType: _selectedType!,
        companyName: _isCompany ? _companyNameController.text.trim() : null,
        industry: _isCompany ? _industryController.text.trim() : null,
        website: _isCompany && _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        description: null,
        location: _locationController.text.trim(),
        locationId: _selectedLocation?.id,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );

      if (!success) {
        _showError(employerProvider.errorMessage ?? 'Failed to create profile');
        return false;
      }

      // 3. Upload photo if selected
      if (_tempImagePath != null) {
        final uploaded = await employerProvider.uploadImage(fromMemory: _tempImagePath);
        if (!uploaded) {
          _showError(employerProvider.errorMessage ?? 'Failed to upload image');
          return false;
        }
      }

      // 4. Submit verification drafts only after Finish (OPTIONAL - don't fail if error)
      if (hasCompleteIdentity) {
        try {
          await verificationProvider.submitGovernmentID(
            idType: _identityIdType,
            idPhotoPath: _identityIdPhotoPath!,
            selfiePhotoPath: _identitySelfiePath!,
          );
          // If verification upload fails, just continue - it's optional
        } catch (e) {
          /*
              Told, not swallowed.

              This printed to the console and carried on, so an employer whose
              ID upload failed finished setup believing it had gone through and
              found out only when a worker asked why they were not verified.
              The worker side of this flow already warns; this did not.

              Still not fatal - the profile itself saved, and verification can
              be retried from the profile - so the flow continues and the
              warning is raised at the end.
          */
          debugPrint('[employer setup] ID verification upload failed: $e');
          _verificationUploadFailed = true;
        }
      }

      if (_isCompany && _businessDocument != null) {
        try {
          final bytes = _businessDocument!['documentBytes'] ?? _businessDocument!['bytes'];
          await verificationProvider.submitDocument(
            type: 'business_reg',
            fileName: (_businessDocument!['documentName'] ??
                _businessDocument!['name']) as String,
            filePath: (_businessDocument!['documentPath'] ??
                _businessDocument!['path']) as String?,
            fileBytes: bytes is List<int> ? bytes : (bytes as List?)?.cast<int>(),
          );
          // If verification upload fails, just continue - it's optional
        } catch (e) {
          // Same as the ID above: reported at the end rather than swallowed.
          debugPrint('[employer setup] business document upload failed: $e');
          _verificationUploadFailed = true;
        }
      }

      await auth.fetchMe();
      return true;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);
    try {
      // Refreshing auth re-derives the home view: employer-only accounts land
      // on workers, while an account that now holds both profiles becomes
      // hybrid and sees jobs AND workers. No focus is forced here.
      /*
          Both providers taken before either await.

          These were read one after the other with an await in between, so the
          second read happened against a context that may already have been
          disposed - reading a provider off a defunct element throws rather
          than returning null.
      */
      /*
          Navigate first, refresh after. The order was the whole bug.

          This refreshed and then navigated. But fetchMe drives
          EmployerProfileRouter, which sits directly under this flow and
          re-derives what it should show the moment the answer changes - so
          the await handed it a finished profile, it swapped this screen for
          MyEmployerProfileScreen, and this State was disposed. The very next
          line is `if (!mounted) return`, so the navigation never ran at all
          and the user was left standing on their own profile wondering why
          finishing setup had put them there.

          The worker flow hit this exact bug and fixed it by going to the
          shell first. This is that fix, applied to the side that kept the old
          order. Everything below is removed so the back gesture cannot walk
          into a setup flow that is finished.
      */
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.home,
        (route) => false,
      );

      // Now the flags, with nothing left underneath to rebuild.
      final auth = context.read<AuthProvider>();
      final employerProfile = context.read<EmployerProfileProvider>();

      await auth.fetchMe();
      await employerProfile.fetchProfile();

      // ScaffoldMessenger is app-scoped, so this survives the route change and
      // lands over the home screen rather than over a screen being disposed.
      if (mounted && _verificationUploadFailed) {
        AppToast.warning(
          context,
          'Your profile is set up, but your document could not be uploaded. '
          'You can retry it from Verification.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  String get _primaryLabel {
    if (_isLastStep) return 'Finish';
    if (_currentStep == 1) return 'Continue';
    return 'Next';
  }

  bool get _canContinue {
    if (_currentStep == 0) return _selectedType != null;
    return !_isSaving;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _stepNumber / _totalSteps;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Profile Setup?'),
            content: const Text(
              'Your profile is not complete. If you leave now, all progress will be discarded.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldExit && mounted) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: _previousStep,
        ),
        title: Text(
          'Step $_stepNumber of $_totalSteps',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.neutral200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildTypeStep(),
          _buildDetailsStep(),
          _buildPhotoStep(),
          if (!_isCompany) _buildIdentityVerificationStep(), // Only for individual
          if (_isCompany) _buildBusinessVerificationStep(), // Only for company
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business_center, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Set up your employer profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose whether you are hiring as a business or as an individual.',
            style: TextStyle(fontSize: 14, color: AppColors.neutral600),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeToggle(EmployerType.company),
                ),
                Expanded(
                  child: _buildTypeToggle(EmployerType.individual),
                ),
              ],
            ),
          ),
          if (_selectedType != null) ...[
            // The panel that used to sit here restated the choice just made
            // and then listed the fields the next screen asks for anyway.
            const SizedBox(height: 12),

            // Said here because this is the last moment it can be changed.
            // The two types require different verification documents, so
            // switching afterwards would invalidate whatever has already been
            // approved — the profile screen shows this locked, and a user who
            // was never told will read that as a missing feature.
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline,
                    size: 15, color: AppColors.neutral500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You can't change this later, so pick the one that matches "
                    'how you will be hiring.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.neutral600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isCompany ? Icons.business : Icons.person,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _isCompany ? 'Business details' : 'Personal details',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCompany
                  ? 'Workers will see these details when they view your jobs.'
                  : 'Workers will see your name and location when you post jobs.',
              style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
            ),
            const SizedBox(height: 32),
            if (_isCompany) ...[
              _textField(
                controller: _companyNameController,
                label: 'Business Name *',
                hint: 'e.g., ABC Construction Co.',
                icon: Icons.business,
                requiredMessage: 'Business name is required',
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _industryController,
                label: 'Industry *',
                hint: 'e.g., Construction, Retail, Cleaning',
                icon: Icons.work_outline,
                requiredMessage: 'Industry is required',
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _websiteController,
                label: 'Website',
                hint: 'https://www.company.com',
                icon: Icons.language,
                keyboardType: TextInputType.url,
              ),
            ] else ...[
              // This is the account name, not a separate employer name.
              //
              // It is prefilled from the account and, once the account's ID has
              // been verified, cannot be edited here. The same name appears on
              // the worker profile, on posted jobs, in chat and against every
              // review — letting the employer step rewrite it would mean a
              // worker could verify as one person, build up reviews, then
              // rename the account and keep the verified badge.
              // Four fields, matching worker setup. Only the last row splits,
              // surname at twice the suffix width — a suffix box the size of
              // a surname box reads as though four characters were expected
              // in both.
              // Surname first, the way every Philippine form asks for it.
              // Read-only once the account has the name; the parts still show
              // which is which rather than collapsing into one box.
              _textField(
                controller: _lastNameController,
                label: 'Last Name *',
                icon: Icons.badge_outlined,
                requiredMessage: _nameIsLocked ? null : 'Last name is required',
                textCapitalization: TextCapitalization.words,
                readOnly: _nameIsLocked,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _firstNameController,
                label: 'First Name *',
                icon: Icons.person,
                requiredMessage: _nameIsLocked ? null : 'First name is required',
                textCapitalization: TextCapitalization.words,
                readOnly: _nameIsLocked,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _middleNameController,
                label: 'Middle Name (optional)',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                readOnly: _nameIsLocked,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _suffixController,
                label: 'Suffix (optional)',
                icon: Icons.more_horiz,
                textCapitalization: TextCapitalization.characters,
                readOnly: _nameIsLocked,
              ),
            ],
            const SizedBox(height: 16),
            // Picker, not free text — keeps employer locations normalized so
            // they match job posts and worker locations.
            LocationPickerField(
              controller: _locationController,
              labelText: 'Location *',
              // City or municipality only - an employer is matched on the
              // city, and a barangay here made two accounts in one city look
              // like different places.
              cityLevel: true,
              // Parent is the source of truth, so the field can reconcile its
              // label when the selection changes from outside.
              selection: _selectedLocation,
              onSelected: (location) =>
                  setState(() => _selectedLocation = location),
              onCleared: () => setState(() => _selectedLocation = null),
              // Checks the *selection*, not just that text is present.
              //
              // The previous validator only required a non-empty string, so
              // typing "Manila" and never picking it from the list passed —
              // and saved an employer with a location label but no location_id,
              // which means no coordinates, no distance, and no matching. The
              // same gap was fixed in job posting; this call site kept its own
              // weaker rule.
              validator: (_) =>
                  _selectedLocation == null ? 'Pick a location from the list' : null,
            ),
            // The About field was removed from setup. It is optional and can
            // be added later from the profile, so it does not belong in the
            // shortest path to a working account.
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStep() {
    // Use temp image path from memory
    final hasImage = _tempImagePath != null && _tempImagePath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isCompany ? Icons.add_business : Icons.add_a_photo,
            size: 64,
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          Text(
            _isCompany ? 'Add a business logo' : 'Add a profile photo',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A photo makes your job posts feel more trustworthy. You can skip this for now.',
            style: TextStyle(fontSize: 14, color: AppColors.neutral600),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: _isCompany ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _isCompany ? BorderRadius.circular(18) : null,
                    border: Border.all(
                      color: hasImage ? AppColors.success : AppColors.primary,
                      width: 3,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(_tempImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Icon(
                          _isCompany ? Icons.business : Icons.person,
                          size: 56,
                          color: AppColors.neutral400,
                        ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    /*
                        Camera as well as gallery.

                        This offered the gallery only, so an employer setting
                        up on the spot could not just take a photo - they had
                        to have one saved already. Every other photo step in
                        the app asks which, so this one does too.

                        maxWidth was also missing here, so a full-resolution
                        gallery image went up uncompressed. Capped now, the
                        same as the worker photo, to stay under the upload
                        limit.
                    */
                    final fromCamera = await showModalBottomSheet<bool>(
                      context: context,
                      builder: (sheet) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_camera_outlined),
                              title: const Text('Take a photo'),
                              onTap: () => Navigator.pop(sheet, true),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: const Text('Choose from gallery'),
                              onTap: () => Navigator.pop(sheet, false),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (fromCamera == null || !mounted) return;

                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source:
                          fromCamera ? ImageSource.camera : ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 80,
                    );
                    if (image != null && mounted) {
                      setState(() => _tempImagePath = image.path);
                    }
                  },
                  icon: Icon(hasImage ? Icons.edit : Icons.upload),
                  label: Text(hasImage ? 'Change Photo' : 'Upload Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityVerificationStep() {
    return _buildVerificationStep(
      icon: Icons.badge,
      title: 'Verify your identity',
      body:
          'Submit a valid Philippine government ID and selfie. This uses the same verification flow as worker profiles.',
      documentType: 'government_id',
      documentTitle: 'Valid Philippine ID',
      documentSubtitle: 'Government-issued ID with selfie',
    );
  }

  Widget _buildBusinessVerificationStep() {
    return _buildVerificationStep(
      icon: Icons.verified_user,
      title: 'Verify your business',
      body:
          'Upload a DTI certificate, SEC registration, or Mayor\'s Permit for admin review.',
      documentType: 'business_reg',
      documentTitle: 'Business Permit',
      documentSubtitle: 'DTI, SEC, or Mayor\'s Permit',
    );
  }

  Widget _buildVerificationStep({
    required IconData icon,
    required String title,
    required String body,
    required String documentType,
    required String documentTitle,
    required String documentSubtitle,
  }) {
    final isIdentity = documentType == 'government_id';
    final hasIdentityDraft =
        _identityIdPhotoPath != null && _identitySelfiePath != null;
    final hasBusinessDraft = _businessDocument != null;
    final hasDraft = isIdentity ? hasIdentityDraft : hasBusinessDraft;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildOnboardingVerificationCard(
            title: documentTitle,
            subtitle: documentSubtitle,
            icon: icon,
            isReady: hasDraft,
            onTap: () async {
              if (isIdentity) {
                // Use onboarding verification screen for government ID
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingVerificationScreen(
                      existingData: {
                        'idType': _identityIdType,
                        'idPhotoPath': _identityIdPhotoPath,
                        'idPhotoName': _identityIdPhotoName,
                        'selfiePhotoPath': _identitySelfiePath,
                        'selfiePhotoName': _identitySelfieName,
                      },
                    ),
                  ),
                );
                if (result == null || !mounted) return;
                setState(() {
                  _identityIdType = result['idType'] as String? ?? _identityIdType;
                  _identityIdPhotoPath = result['idPhotoPath'] as String?;
                  _identityIdPhotoName = result['idPhotoName'] as String?;
                  _identitySelfiePath = result['selfiePhotoPath'] as String?;
                  _identitySelfieName = result['selfiePhotoName'] as String?;
                });
              } else {
                // For business documents, use file picker directly
                final vp = context.read<VerificationProvider>();
                final result = await vp.pickDocument();
                if (result != null && mounted) {
                  setState(() {
                    _businessDocument = {
                      'documentPath': result['path'] as String?,
                      'documentName': result['name'] as String,
                      'documentBytes': result['bytes'],
                    };
                  });
                }
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Verification will be submitted when you tap Finish.',
            style: const TextStyle(fontSize: 12, color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isReady,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.neutral200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isReady ? Icons.check_circle : icon,
                  color: isReady ? AppColors.success : AppColors.neutral600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900,
                      ),
                    ),
                    if (!isReady)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
                      ),
                  ],
                ),
              ),
              if (isReady)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.neutral400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // Allow skip on photo (step 2) and verification steps (step 3)
    final canSkip = _currentStep >= 2;
    
    // Hide skip button if user has captured verification photos/documents (in memory draft)
    final hasIdentityDraft = _identityIdPhotoPath != null && _identitySelfiePath != null;
    final hasBusinessDraft = _businessDocument != null;
    
    // Only check verification status on the verification step (step 3)
    bool showSkipButton = canSkip;
    if (_isLastStep) {
      final hasDraft = _isCompany ? hasBusinessDraft : hasIdentityDraft;
      showSkipButton = !hasDraft; // Hide skip if user captured photos/documents
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (showSkipButton) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () {
                    if (_isLastStep) {
                      // On last step, skip means finish without verification
                      _handlePrimaryAction();
                    } else {
                      _goToStep(_currentStep + 1);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                    side: const BorderSide(color: AppColors.neutral300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isLastStep ? 'Skip & Finish' : 'Skip'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _canContinue ? _handlePrimaryAction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.neutral300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _primaryLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(EmployerType type) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (_currentStep >= _pageCount) _currentStep = _pageCount - 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected ? Colors.white : AppColors.neutral600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [hint] is optional — pass one only when it teaches a format or unit the
  /// label can't. "Full Name" with "e.g., Juan Dela Cruz" under it is the label
  /// said twice.
  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    String? requiredMessage,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.neutral500, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: requiredMessage == null
          ? null
          : (value) {
              if (value == null || value.trim().isEmpty) {
                return requiredMessage;
              }
              if (value.trim().length < 2) {
                return 'Please enter at least 2 characters';
              }
              return null;
            },
    );
  }
}
