import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pin_location_match.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../providers/verification_provider.dart';
import '../../../data/models/skill_model.dart';
import '../../../data/models/worker_certification_model.dart';
import '../../../data/models/worker_license_model.dart';
import '../../../data/services/api_client.dart';
import '../../../core/navigation/app_router.dart';
import '../../profile/screens/add_skills_screen.dart';
import '../../profile/screens/onboarding_verification_screen.dart';
import '../../../core/widgets/app_toast.dart';

/// Worker Profile Setup Flow - 6 Step Onboarding
/// 
/// Steps:
/// 1. Location (required)
/// 2. Category + Skills (required)
/// 3. Experience (optional)
/// 4. Certifications (optional)
/// 5. Profile Photo (optional)
/// 6. Verification (optional)
class WorkerSetupFlowScreen extends StatefulWidget {
  final int resumeStep;
  
  const WorkerSetupFlowScreen({super.key, this.resumeStep = 0});

  @override
  State<WorkerSetupFlowScreen> createState() => _WorkerSetupFlowScreenState();
}

class _WorkerSetupFlowScreenState extends State<WorkerSetupFlowScreen> {
  late PageController _pageController;
  late int _currentStep;
  late TextEditingController _locationController;
  late TextEditingController _nameController;
  
  // Form data - ALL stored in memory until Finish
  String? _location;
  String? _userName;
  List<SkillModel> _selectedSkills = [];
  List<Map<String, dynamic>> _tempExperiences = [];
  List<Map<String, dynamic>> _tempCertifications = [];
  List<Map<String, dynamic>> _tempLicenses = [];
  String? _tempProfilePhotoPath;
  String _tempGovernmentIdType = 'Philippine National ID';
  String? _tempIdPhotoPath;
  String? _tempIdPhotoName;
  String? _tempSelfiePhotoPath;
  String? _tempSelfiePhotoName;
  bool _isSaving = false;

  /// Which button started the save, so only that one shows a spinner.
  ///
  /// Both buttons used to read the same `_isSaving` flag, so finishing made
  /// "Skip & Finish" spin too and skipping made "Finish" spin — two spinners
  /// for one action, and no way to tell which one you actually pressed. They
  /// still share `_isSaving` for *disabling*, which is correct: while either
  /// is running neither should be pressable.
  bool _finishPressed = false;

  /// Set when the optional ID upload fails. Setup still completes, but the user
  /// is warned so they can retry from the verification screen.
  bool _verificationUploadFailed = false;

  /// Structured location chosen from the picker (PSGC id + coordinates).
  LocationModel? _selectedLocation;

  /// Exact pin for where this worker is based, if they set one. Overrides the
  /// town/barangay centroid — without it, every worker in a town shares one
  /// point and jobs there all read 0 km away.
  double? _pinnedLat;
  double? _pinnedLng;
  
  @override
  void initState() {
    super.initState();
    _currentStep = widget.resumeStep;
    _pageController = PageController(initialPage: widget.resumeStep);
    
    // Initialize controllers FIRST to avoid red error
    _locationController = TextEditingController();
    _nameController = TextEditingController();
    
    // Load existing data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final provider = context.read<WorkerProfileProvider>();
      final verificationProvider = context.read<VerificationProvider>();
      
      // Fetch fresh data
      await authProvider.fetchMe();
      await provider.fetchProfile();
      await provider.fetchCategories();
      await verificationProvider.fetchVerifications(); // Fetch verification status
      
      if (!mounted) return;

      // Only prefill fields the user has not already started filling in.
      //
      // These four awaits take a second or two, and the user can type during
      // that time. Assigning unconditionally overwrote their input with the
      // server value — usually empty — so a name typed straight away vanished.
      if (_nameController.text.isEmpty) {
        _userName = authProvider.user?['name'] as String?;
        _nameController.text = _userName ?? '';
      }

      if (_locationController.text.isEmpty) {
        _location = provider.location;
        _locationController.text = _location ?? '';
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _locationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Surfaces a failed save. Setup takes several minutes to fill in, so a
  /// silent failure at the end is the worst possible outcome.
  void _showSetupError(Object error) {
    if (!mounted) return;

    final message = error.toString().replaceFirst('Exception: ', '');
    AppToast.error(context, 'Could not finish setup: $message');
  }

  void _nextStep() {
    if (_currentStep < 6) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipStep() {
    // Skip optional steps
    if (_currentStep >= 2) {
      _nextStep();
    }
  }

  Future<void> _finishSetup() async {
    /*
        Navigate first, refresh after.

        The order was the whole bug. This used to call fetchMe and navigate
        afterwards - but fetchMe drives the proxy provider, the router sitting
        under this flow immediately re-derives what it should be showing, and
        for one frame it swapped the setup screen for the finished profile.
        Then the navigation fired and threw that away. The flash was a real
        screen being built and discarded.

        Going to the shell first means the setup route and the router beneath
        it are gone before anything can refresh, so there is nothing left to
        rebuild and nothing to see.

        Everything below is removed so the back gesture cannot walk into a
        setup flow that is finished.
    */
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.home,
      (route) => false,
    );

    /*
        Now the flags.

        AppModeProvider learns the worker profile exists and re-derives the
        home view: worker-only accounts land on jobs, an account that now holds
        both becomes hybrid and sees both. No focus is forced - that would
        defeat the unified home.

        Not awaited before navigating, and it does not need to be: the home
        screen loads its own data on mount, and this only has to land before
        the first frame that depends on it.
    */
    await context.read<AuthProvider>().fetchMe();

    if (mounted && _verificationUploadFailed) {
      // ScaffoldMessenger is app-scoped, so this survives the route change and
      // arrives over the home screen rather than over a screen being disposed.
      AppToast.warning(
        context,
        'Your profile is set up, but your ID could not be uploaded. '
        'You can retry it from Verification.',
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: // Name + location + exact pin
        // _selectedLocation, not just non-empty text: typed text that was
        // never picked from the suggestions has no location_id, so the profile
        // saves with no coordinates and the worker is invisible to every
        // distance and proximity calculation.
        return _nameController.text.trim().isNotEmpty &&
            _selectedLocation != null &&
            _pinnedLat != null &&
            _pinnedLng != null;
      case 1: // Skills
        return _selectedSkills.isNotEmpty;
      default:
        return true; // Optional steps can always proceed
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = 7;
    final progress = (_currentStep + 1) / totalSteps;
    
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
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
                onPressed: _previousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.neutral900),
                onPressed: () async {
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
              ),
        title: Text(
          'Step ${_currentStep + 1} of $totalSteps',
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
            backgroundColor: AppColors.neutral200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentStep = page),
        children: [
          _buildLocationStep(),
          _buildSkillsStep(),
          _buildExperienceStep(),
          _buildCertificationsStep(),
          _buildLicensesStep(),
          _buildPhotoStep(),
          _buildVerificationStep(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let employers know who you are and where you work.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Name (EDITABLE)
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) {
              _userName = value;
              setState(() {}); // Need setState to update button state
            },
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Location picker — was a free-text field, which produced values that
          // never matched between workers and job posts.
          LocationPickerField(
            controller: _locationController,
            labelText: 'Barangay, City or Municipality *',
            hintText: 'Search your barangay or city',
            selection: _selectedLocation,
            onSelected: (location) {
              _location = location.displayName;
              _selectedLocation = location;
              // A new place invalidates a pin dropped for the old one.
              _pinnedLat = null;
              _pinnedLng = null;
              setState(() {}); // Refresh the Next button's enabled state
            },
            // Text edited after choosing — drop the id so the profile can't
            // save one place's coordinates under another place's name.
            onCleared: () => setState(() {
              _selectedLocation = null;
              _pinnedLat = null;
              _pinnedLng = null;
            }),
          ),
          const SizedBox(height: 12),
          _buildWorkerPinRow(),
        ],
      ),
    );
  }

  /// Required exact pin for where the worker is based.
  ///
  /// Without it every worker in a town sits on that town's single centroid, so
  /// a job in the same town reads the same distance for all of them — which
  /// takes the location component of matching out of play entirely.
  /*
      A pin button, the size of a button.

      This was a full-width card: tinted background, border, an icon in a box,
      a title, a sentence underneath it and a chevron - all to say "pin your
      location", which is what the pin icon already says. Every maps app on
      the phone does this with one small control, because there is nothing to
      explain.

      So it is a pill now. Pin icon, two words, no fill and no highlight; it
      only picks up a colour once a pin exists, which is the single piece of
      state worth showing. Clearing it is the small x beside it rather than a
      full-height IconButton that set the row's height.
  */
  Widget _buildWorkerPinRow() {
    final hasPin = _pinnedLat != null && _pinnedLng != null;
    final canPin = _selectedLocation != null;

    final tint = !canPin
        ? AppColors.neutral400
        : (hasPin ? AppColors.success : AppColors.primary);

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: canPin ? _openWorkerPinPicker : null,
            icon: Icon(
              hasPin ? Icons.where_to_vote : Icons.add_location_alt_outlined,
              size: 18,
            ),
            label: Text(hasPin ? 'Pinned' : 'Pin location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tint,
              side: BorderSide(color: tint.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasPin)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.neutral500,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              tooltip: 'Remove pin',
              onPressed: () => setState(() {
                _pinnedLat = null;
                _pinnedLng = null;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _openWorkerPinPicker() async {
    final result = await Navigator.pushNamed(
      context,
      '/pin-location',
      arguments: {
        'latitude': _pinnedLat ?? _selectedLocation?.latitude,
        'longitude': _pinnedLng ?? _selectedLocation?.longitude,
        'label': _selectedLocation?.displayName,
      },
    );

    if (result is! Map || !mounted) return;

    final lat = (result['latitude'] as num?)?.toDouble();
    final lng = (result['longitude'] as num?)?.toDouble();
    final resolved = result['resolved'] as LocationModel?;

    if (lat == null || lng == null) return;

    // This check existed only in job posting, which is how a worker could pick
    // "Urdaneta City" from the list, pin Manila on the map, and save both. The
    // profile then displayed Urdaneta while its coordinates sat 200km away, so
    // every distance and match was computed against a place the profile never
    // showed.
    final movedElsewhere = resolved != null &&
        _selectedLocation != null &&
        !isSamePlace(resolved, _selectedLocation!);

    if (movedElsewhere) {
      final useResolved = await _confirmWorkerLocationChange(resolved);
      if (!mounted) return;

      if (useResolved) {
        setState(() {
          _selectedLocation = resolved;
          _location = resolved.displayName;
          _pinnedLat = lat;
          _pinnedLng = lng;
        });
      }
      // Declined: keep no pin rather than one that contradicts the label.
      return;
    }

    setState(() {
      _pinnedLat = lat;
      _pinnedLng = lng;
    });
  }

  /// Asked only when the pin disagrees with the chosen place. Keeping both
  /// would be the bug; this makes the worker say which one is right.
  Future<bool> _confirmWorkerLocationChange(LocationModel resolved) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pin is somewhere else'),
            content: Text(
              'Your pin is in ${resolved.displayName}, not '
              '${_selectedLocation?.displayName ?? 'the location you chose'}.\n\n'
              'Use the pinned location instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep my choice'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use the pin'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildSkillsStep() {
    final provider = context.watch<WorkerProfileProvider>();
    
    // Group skills by category for display
    final Map<String, List<SkillModel>> groupedSkills = {};
    for (var skill in _selectedSkills) {
      // Find category name from provider's categories list
      String categoryName = 'Other';
      try {
        final category = provider.categories.firstWhere((c) => c.id == skill.categoryId);
        categoryName = category.name;
      } catch (e) {
        // Category not found, use 'Other'
      }
      groupedSkills.putIfAbsent(categoryName, () => []).add(skill);
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.build_circle, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          const Text(
            'What are your skills?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your category and skills. This helps employers find you.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Selected skills preview with categories
          if (_selectedSkills.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Selected Skills',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedSkills.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Show grouped by category
                  ...groupedSkills.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((skill) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                skill.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Add skills button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Convert SkillModel list to skill names for AddSkillsScreen
                final skillNames = _selectedSkills.map((s) => s.name).toList();
                final result = await Navigator.push<List<SkillModel>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSkillsScreen(
                      initialSkills: skillNames,
                      draftOnly: true,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _selectedSkills = result);
                }
              },
              icon: Icon(_selectedSkills.isEmpty ? Icons.add : Icons.edit, size: 20),
              label: Text(_selectedSkills.isEmpty ? 'Add Skills' : 'Edit Skills'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    // Use temp experiences from memory, NOT from provider
    final experiences = _tempExperiences;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.work, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Work Experience',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your work history to stand out. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Experience preview
          if (experiences.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Experience',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${experiences.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...experiences.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exp = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp['jobTitle'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    exp['company'] as String,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${exp['startDate']} - ${exp['endDate']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.neutral500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                              onPressed: () async {
                                final result = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ExperienceFormScreen(existing: exp),
                                  ),
                                );
                                if (result != null && mounted) {
                                  setState(() => _tempExperiences[index] = result);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                              onPressed: () {
                                setState(() => _tempExperiences.removeAt(index));
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Go directly to form
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _ExperienceFormScreen(),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _tempExperiences.add(result));
                }
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Experience'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationsStep() {
    // Use temp certifications from memory
    final certifications = _tempCertifications;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified, size: 64, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            'Certifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add professional certifications to boost your profile. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Certifications preview
          if (certifications.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Certifications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${certifications.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...certifications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cert = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cert['certification_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cert['issuing_organization'] as String,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  if (cert['issue_date'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issued: ${cert['issue_date']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.neutral500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                              onPressed: () async {
                                final result = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _CertificationFormScreen(existing: cert),
                                  ),
                                );
                                if (result != null && mounted) {
                                  setState(() => _tempCertifications[index] = result);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                              onPressed: () {
                                setState(() => _tempCertifications.removeAt(index));
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Go directly to form
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _CertificationFormScreen(),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _tempCertifications.add(result));
                }
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Certifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicensesStep() {
    // Use temp licenses from memory
    final licenses = _tempLicenses;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_membership, size: 64, color: AppColors.warning),
          const SizedBox(height: 24),
          const Text(
            'Licenses',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add any professional licences you hold. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Licenses preview
          if (licenses.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Added Licenses',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${licenses.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...licenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final license = entry.value;
                    return Column(
                      children: [
                        if (index > 0) const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    license['license_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    license['issuing_authority'] as String,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                  if (license['issue_date'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Issued: ${license['issue_date']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.neutral500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                              onPressed: () async {
                                final result = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _LicenseFormScreen(existing: license),
                                  ),
                                );
                                if (result != null && mounted) {
                                  setState(() => _tempLicenses[index] = result);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                              onPressed: () {
                                setState(() => _tempLicenses.removeAt(index));
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Go directly to form
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _LicenseFormScreen(),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _tempLicenses.add(result));
                }
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Licenses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    // Use temp photo from memory
    final hasPhoto = _tempProfilePhotoPath != null && _tempProfilePhotoPath!.isNotEmpty;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.camera_alt, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          const Text(
            'Add a profile photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Profiles with photos get 5x more views! (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: hasPhoto ? Colors.transparent : AppColors.neutral200,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasPhoto ? AppColors.success : AppColors.primary,
                      width: 3,
                    ),
                    image: hasPhoto
                        ? DecorationImage(
                            image: FileImage(File(_tempProfilePhotoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person,
                          size: 60,
                          color: AppColors.neutral400,
                        ),
                ),
                const SizedBox(height: 16),
                if (hasPhoto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Photo selected',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final choice = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Choose Photo'),
                        content: const Text('Select photo source'),
                        actions: [
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ],
                      ),
                    );
                    if (choice != null && mounted) {
                      // Pick image and store path in memory, DON'T upload yet
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: choice ? ImageSource.camera : ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (image != null && mounted) {
                        setState(() => _tempProfilePhotoPath = image.path);
                      }
                    }
                  },
                  icon: Icon(hasPhoto ? Icons.edit : Icons.add_a_photo),
                  label: Text(hasPhoto ? 'Change Photo' : 'Upload Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildVerificationStep() {
    final hasDraftVerification =
        _tempIdPhotoPath != null && _tempSelfiePhotoPath != null;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Verify Your Identity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get verified to increase trust and unlock more opportunities. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 32),
          
          // Verification status card - similar to employer design
          if (hasDraftVerification) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: AppColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Ready',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Will be submitted when you tap Finish',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Use onboarding verification screen
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingVerificationScreen(
                      existingData: {
                        'idType': _tempGovernmentIdType,
                        'idPhotoPath': _tempIdPhotoPath,
                        'idPhotoName': _tempIdPhotoName,
                        'selfiePhotoPath': _tempSelfiePhotoPath,
                        'selfiePhotoName': _tempSelfiePhotoName,
                      },
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _tempGovernmentIdType = result['idType'] as String? ?? 'Philippine National ID';
                    _tempIdPhotoPath = result['idPhotoPath'] as String?;
                    _tempIdPhotoName = result['idPhotoName'] as String?;
                    _tempSelfiePhotoPath = result['selfiePhotoPath'] as String?;
                    _tempSelfiePhotoName = result['selfiePhotoName'] as String?;
                  });
                }
              },
              icon: Icon(hasDraftVerification ? Icons.edit : Icons.add_a_photo, size: 20),
              label: Text(hasDraftVerification ? 'Edit Verification' : 'Start Verification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (!hasDraftVerification) ...[
            const SizedBox(height: 12),
            const Text(
              'Verification will be submitted when you tap Finish.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 6;
    final isOptionalStep = _currentStep >= 2; // Include last step (verification is optional)
    
    // Hide skip button if user has captured verification photos (in memory draft)
    final hasDraftVerification = _tempIdPhotoPath != null && _tempSelfiePhotoPath != null;
    
    // Only check verification status on the verification step (step 6)
    bool showSkipButton = isOptionalStep;
    if (isLastStep) {
      showSkipButton = !hasDraftVerification; // Hide skip if user captured photos
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
            // Skip button (only on optional steps AND no existing verification)
            if (showSkipButton) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () async {
                    if (isLastStep) {
                      // On last step, skip means finish without verification
                      setState(() {
                        _isSaving = true;
                        _finishPressed = false;
                      });
                      try {
                        await _saveAllDataAndComplete();
                      } catch (e) {
                        _showSetupError(e);
                      } finally {
                        if (mounted) {
                          setState(() => _isSaving = false);
                        }
                      }
                    } else {
                      _skipStep();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral600,
                    side: BorderSide(color: AppColors.neutral300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // Spins only when *this* button started the save.
                  child: _isSaving && isLastStep && !_finishPressed
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neutral600),
                          ),
                        )
                      : Text(isLastStep ? 'Skip & Finish' : 'Skip'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Next/Finish button
            Expanded(
              child: ElevatedButton(
                onPressed: (_canProceed && !_isSaving)
                    ? () async {
                        // Moving between steps is instant — nothing is saved
                        // until Finish. Flipping _isSaving here made the button
                        // flash a spinner on every single Next tap.
                        if (!isLastStep) {
                          _nextStep();
                          return;
                        }

                        setState(() {
                          _isSaving = true;
                          _finishPressed = true;
                        });
                        try {
                          await _saveAllDataAndComplete();
                        } catch (e) {
                          // Previously only print()ed, so a failed save looked
                          // to the user like the button simply did nothing.
                          _showSetupError(e);
                        } finally {
                          if (mounted) {
                            setState(() => _isSaving = false);
                          }
                        }
                      }
                    : null,
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
                // Spins only when *this* button started the save.
                child: _isSaving && _finishPressed
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isLastStep ? 'Finish' : 'Next',
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

  Future<void> _saveAllDataAndComplete() async {
    final provider = context.read<WorkerProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    final verificationProvider = context.read<VerificationProvider>();
    final apiClient = ApiClient(); // Create ApiClient instance
    
    try {
      // Removed validation that blocks incomplete verification - now truly optional
      final hasCompleteVerification =
          _tempIdPhotoPath != null && _tempSelfiePhotoPath != null;

      // 1. Save name to users table
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await authProvider.updateMe(name: name);
      }
      
      // 2. Save location (this creates profile with setup_completed=false)
      final location = _locationController.text.trim();
      if (location.isNotEmpty) {
        // Send the picker's structured location, not just the display text —
        // without location_id the profile has no coordinates and every
        // "x km away" / proximity match for this worker comes out empty.
        final success = await provider.updateLocation(
          location,
          locationId: _selectedLocation?.id,
          // A dropped pin beats the centroid; without one the town's own
          // coordinates are used, which is what keeps pinning optional.
          latitude: _pinnedLat ?? _selectedLocation?.latitude,
          longitude: _pinnedLng ?? _selectedLocation?.longitude,
        );
        if (!success && mounted) {
          throw Exception(provider.errorMessage ?? 'Failed to save location');
        }
      }
      
      // 3. Save skills
      if (_selectedSkills.isNotEmpty) {
        await provider.saveSkillsWithCategories(_selectedSkills);
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // 4. Save experiences
      for (var exp in _tempExperiences) {
        await provider.createExperience(exp);
      }
      
      // 5. Save certifications
      for (var cert in _tempCertifications) {
        await provider.addCertification(
          WorkerCertificationModel(
            userId: 0,
            certificationName: cert['certification_name'] as String,
            issuingOrganization: cert['issuing_organization'] as String,
            issueDate: cert['issue_date'] != null ? DateTime.parse(cert['issue_date'] as String) : null,
          ),
          filePath: cert['filePath'] as String?,
        );
      }
      
      // 6. Save licenses
      for (var lic in _tempLicenses) {
        await provider.addLicense(
          WorkerLicenseModel(
            userId: 0,
            licenseName: lic['license_name'] as String,
            licenseNumber: lic['license_number'] as String? ?? 'N/A',
            issuingAuthority: lic['issuing_authority'] as String,
            issueDate: lic['issue_date'] != null ? DateTime.parse(lic['issue_date'] as String) : null,
          ),
          filePath: lic['filePath'] as String?,
        );
      }
      
      // 7. Upload profile photo
      if (_tempProfilePhotoPath != null) {
        final formData = FormData.fromMap({
          'photo': await MultipartFile.fromFile(
            _tempProfilePhotoPath!,
            filename: 'profile.jpg',
          ),
        });
        await apiClient.post('/worker/profile/photo', data: formData);
      }

      // 8. Submit verification draft only after Finish (OPTIONAL - don't fail if error)
      if (hasCompleteVerification) {
        try {
          await verificationProvider.submitGovernmentID(
            idType: _tempGovernmentIdType,
            idPhotoPath: _tempIdPhotoPath!,
            selfiePhotoPath: _tempSelfiePhotoPath!,
          );
          // If verification upload fails, just continue - it's optional
        } catch (e) {
          // Non-blocking, but the user must be told: they submitted an ID and
          // would otherwise finish believing verification was under way.
          _verificationUploadFailed = true;
        }
      }
      
      // 9. Mark setup as complete
      await provider.completeSetup();
      
      // 10. Finish
      await _finishSetup();
      
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to save profile: $e');
      }
      rethrow;
    }
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// INLINE FORM SCREENS - Used during onboarding only
// ═══════════════════════════════════════════════════════════════════════════

/// Experience form - add or edit
class _ExperienceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ExperienceFormScreen({this.existing});

  @override
  State<_ExperienceFormScreen> createState() => _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends State<_ExperienceFormScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _descCtrl;
  bool _isPresent = false;

  @override
  void initState() {
    super.initState();
    final exp = widget.existing;
    _titleCtrl = TextEditingController(text: exp?['jobTitle'] as String? ?? '');
    _companyCtrl = TextEditingController(text: exp?['company'] as String? ?? '');
    _startCtrl = TextEditingController(text: exp?['startDate'] as String? ?? '');
    _endCtrl = TextEditingController(text: exp?['endDate'] as String? ?? '');
    _descCtrl = TextEditingController(text: exp?['description'] as String? ?? '');
    _isPresent = (exp?['endDate'] as String? ?? '') == 'Present';
    for (final c in [_titleCtrl, _companyCtrl, _startCtrl, _endCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty &&
      _companyCtrl.text.trim().isNotEmpty &&
      _startCtrl.text.trim().isNotEmpty &&
      (_isPresent || _endCtrl.text.trim().isNotEmpty);

  Future<void> _pickDate(TextEditingController ctrl, String label) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      helpText: label,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.neutral900,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => ctrl.text = '${picked.month}/${picked.year}');
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'jobTitle': _titleCtrl.text.trim(),
      'company': _companyCtrl.text.trim(),
      'startDate': _startCtrl.text.trim(),
      'endDate': _isPresent ? 'Present' : _endCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing != null ? 'Edit Experience' : 'Add Experience',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(_titleCtrl, 'Job Title', ''),
                  const SizedBox(height: 16),
                  _field(_companyCtrl, 'Company / Employer', ''),
                  const SizedBox(height: 16),
                  _datePicker(_startCtrl, 'Start Date', 'Select Start Date'),
                  const SizedBox(height: 16),
                  if (!_isPresent) _datePicker(_endCtrl, 'End Date', 'Select End Date'),
                  Row(
                    children: [
                      Checkbox(
                        value: _isPresent,
                        onChanged: (v) => setState(() {
                          _isPresent = v ?? false;
                          if (_isPresent) _endCtrl.clear();
                        }),
                        activeColor: AppColors.primary,
                      ),
                      const Text('Currently working here', style: TextStyle(fontSize: 14, color: AppColors.neutral700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _deco('Description (Optional)', 'Describe your responsibilities...'),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) => TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.words,
        decoration: _deco(label, hint),
      );

  Widget _datePicker(TextEditingController ctrl, String label, String dlgTitle) => TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl, dlgTitle),
        decoration: _deco(label, 'MM/YYYY').copyWith(
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.neutral500),
        ),
      );

  InputDecoration _deco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}

/// Certification form - add or edit
class _CertificationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _CertificationFormScreen({this.existing});

  @override
  State<_CertificationFormScreen> createState() => _CertificationFormScreenState();
}

class _CertificationFormScreenState extends State<_CertificationFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orgCtrl;
  late final TextEditingController _dateCtrl;
  String? _filePath;
  String? _fileName;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final cert = widget.existing;
    _nameCtrl = TextEditingController(text: cert?['certification_name'] as String? ?? '');
    _orgCtrl = TextEditingController(text: cert?['issuing_organization'] as String? ?? '');
    _dateCtrl = TextEditingController(text: cert?['issue_date'] as String? ?? '');
    _filePath = cert?['filePath'] as String?;
    _fileName = cert?['fileName'] as String?;
    _confirmed = widget.existing != null;
    for (final c in [_nameCtrl, _orgCtrl, _dateCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _orgCtrl.text.trim().isNotEmpty &&
      _dateCtrl.text.trim().isNotEmpty &&
      (_filePath != null && _confirmed);

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
        _fileName = result.files.first.name;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.neutral900,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'certification_name': _nameCtrl.text.trim(),
      'issuing_organization': _orgCtrl.text.trim(),
      'issue_date': _dateCtrl.text.trim(),
      'filePath': _filePath,
      'fileName': _fileName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing != null ? 'Edit Certification' : 'Add Certification',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(_nameCtrl, 'Certification Name', ''),
                  const SizedBox(height: 16),
                  _field(_orgCtrl, 'Issued By', ''),
                  const SizedBox(height: 16),
                  _datePicker(_dateCtrl, 'Date Issued', 'Select Issue Date'),
                  const SizedBox(height: 24),
                  _uploadBox(),
                  const SizedBox(height: 20),
                  if (_filePath != null) _confirmCheck(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) => TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.words,
        decoration: _deco(label, hint),
      );

  Widget _datePicker(TextEditingController ctrl, String label, String dlgTitle) => TextField(
        controller: ctrl,
        readOnly: true,
        onTap: _selectDate,
        decoration: _deco(label, 'YYYY-MM-DD').copyWith(
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.neutral500),
        ),
      );

  Widget _uploadBox() {
    final hasFile = _fileName != null;
    
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.neutral300,
            width: hasFile ? 2 : 1.5,
          ),
        ),
        child: hasFile
            ? Column(
                children: [
                  if (_isImage()) ...[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.file(
                        File(_filePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ] else ...[
                    Container(
                      height: 140,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.error),
                          const SizedBox(height: 8),
                          Text(_fileName ?? '',
                              style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fileName ?? 'Document selected',
                            style: const TextStyle(fontSize: 13.5, color: AppColors.success),
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _filePath = null;
                            _fileName = null;
                            _confirmed = widget.existing != null;
                          }),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  const Icon(Icons.upload_file_outlined, size: 40, color: AppColors.neutral400),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to upload certificate',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral700),
                  ),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG, or PDF — max 5MB',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral400)),
                ]),
              ),
      ),
    );
  }

  bool _isImage() {
    if (_fileName == null) return false;
    final ext = _fileName!.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(ext);
  }

  Widget _confirmCheck() {
    return GestureDetector(
      onTap: () => setState(() => _confirmed = !_confirmed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _confirmed ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _confirmed ? AppColors.primary : AppColors.neutral400),
            ),
            child: _confirmed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'I confirm this document is genuine. Submitting fake documents will result in permanent account ban and may be reported to authorities.',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}

/// License form - add or edit
class _LicenseFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LicenseFormScreen({this.existing});

  @override
  State<_LicenseFormScreen> createState() => _LicenseFormScreenState();
}

class _LicenseFormScreenState extends State<_LicenseFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _authorityCtrl;
  late final TextEditingController _dateCtrl;
  String? _filePath;
  String? _fileName;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final lic = widget.existing;
    _nameCtrl = TextEditingController(text: lic?['license_name'] as String? ?? '');
    _authorityCtrl = TextEditingController(text: lic?['issuing_authority'] as String? ?? '');
    _dateCtrl = TextEditingController(text: lic?['issue_date'] as String? ?? '');
    _filePath = lic?['filePath'] as String?;
    _fileName = lic?['fileName'] as String?;
    _confirmed = widget.existing != null;
    for (final c in [_nameCtrl, _authorityCtrl, _dateCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _authorityCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _authorityCtrl.text.trim().isNotEmpty &&
      _dateCtrl.text.trim().isNotEmpty &&
      (_filePath != null && _confirmed);

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
        _fileName = result.files.first.name;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.neutral900,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(context, {
      'license_name': _nameCtrl.text.trim(),
      'license_number': 'N/A',
      'issuing_authority': _authorityCtrl.text.trim(),
      'issue_date': _dateCtrl.text.trim(),
      'filePath': _filePath,
      'fileName': _fileName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing != null ? 'Edit License' : 'Add License',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(_nameCtrl, 'License Name', ''),
                  const SizedBox(height: 16),
                  _field(_authorityCtrl, 'Issued By', ''),
                  const SizedBox(height: 16),
                  _datePicker(_dateCtrl, 'Date Issued', 'Select Issue Date'),
                  const SizedBox(height: 24),
                  _uploadBox(),
                  const SizedBox(height: 20),
                  if (_filePath != null) _confirmCheck(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) => TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.words,
        decoration: _deco(label, hint),
      );

  Widget _datePicker(TextEditingController ctrl, String label, String dlgTitle) => TextField(
        controller: ctrl,
        readOnly: true,
        onTap: _selectDate,
        decoration: _deco(label, 'YYYY-MM-DD').copyWith(
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.neutral500),
        ),
      );

  Widget _uploadBox() {
    final hasFile = _fileName != null;
    
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.neutral300,
            width: hasFile ? 2 : 1.5,
          ),
        ),
        child: hasFile
            ? Column(
                children: [
                  if (_isImage()) ...[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Image.file(
                        File(_filePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ] else ...[
                    Container(
                      height: 140,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 56, color: AppColors.error),
                          const SizedBox(height: 8),
                          Text(_fileName ?? '',
                              style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fileName ?? 'Document selected',
                            style: const TextStyle(fontSize: 13.5, color: AppColors.success),
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _filePath = null;
                            _fileName = null;
                            _confirmed = widget.existing != null;
                          }),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  const Icon(Icons.upload_file_outlined, size: 40, color: AppColors.neutral400),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to upload license',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.neutral700),
                  ),
                  const SizedBox(height: 4),
                  const Text('JPG, PNG, or PDF — max 5MB',
                      style: TextStyle(fontSize: 12, color: AppColors.neutral400)),
                ]),
              ),
      ),
    );
  }

  bool _isImage() {
    if (_fileName == null) return false;
    final ext = _fileName!.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png'].contains(ext);
  }

  Widget _confirmCheck() {
    return GestureDetector(
      onTap: () => setState(() => _confirmed = !_confirmed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _confirmed ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _confirmed ? AppColors.primary : AppColors.neutral400),
            ),
            child: _confirmed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'I confirm this document is genuine. Submitting fake documents will result in permanent account ban and may be reported to authorities.',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
