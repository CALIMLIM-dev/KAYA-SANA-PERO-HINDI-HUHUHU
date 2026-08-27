import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pin_location_match.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/widgets/app_toast.dart';

/// Post Job Screen - Clean, professional design following industry best practices
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Load the real category list before the picker can be opened.
      context.read<WorkerProfileProvider>().fetchCategories();
      _prefillLocationFromProfile();
    });
  }

  /// Most jobs are at or near the employer's own base, so start there and let
  /// them change it. Only prefills when the profile carries a real
  /// location_id — a bare display string would post a job with no coordinates.
  Future<void> _prefillLocationFromProfile() async {
    if (_locationController.text.trim().isNotEmpty) return;

    final provider = context.read<EmployerProfileProvider>();

    // The profile loads asynchronously, so on a cold open it is still null
    // when this first frame runs — waiting for it is the difference between
    // the prefill working and silently not happening.
    if (provider.profile == null) {
      await provider.fetchProfile();
      if (!mounted) return;
    }

    final profile = provider.profile;
    if (profile == null || profile.locationId == null) return;
    if (profile.location.isEmpty) return;
    // The user may have typed while we waited.
    if (_locationController.text.trim().isNotEmpty) return;

    // The profile stores coordinates only when the employer dropped a pin, so
    // usually they're null — resolve the town's own centroid instead, or the
    // pin map opens zoomed out on the whole country with nothing to aim at.
    var lat = profile.latitude;
    var lng = profile.longitude;

    if (lat == null || lng == null) {
      final town =
          await context.read<LocationProvider>().byId(profile.locationId!);
      if (!mounted) return;
      lat = town?.latitude;
      lng = town?.longitude;
    }

    setState(() {
      // Location only — the picker writes the label itself. Writing it here
      // raced its listener and cleared the selection immediately, which is why
      // the prefill looked like it never happened.
      _selectedLocation = LocationModel(
        id: profile.locationId!,
        name: profile.location,
        displayName: profile.location,
        type: 'city',
        latitude: lat,
        longitude: lng,
      );
    });
  }

  final _formKey = GlobalKey<FormState>();

  /*
      Anchors, so a refusal can point at what it is refusing.

      Posting a job used to fail with a toast naming the problem and nothing
      else. On a form this long the field it meant was usually off-screen, so
      the employer read "please pick the job location", saw no location field,
      and had to scroll looking for the red one. The toast is fine; it just
      needs to arrive with the field it is talking about.
  */
  final _basicsKey = GlobalKey();
  final _photosKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _scheduleKey = GlobalKey();

  /// Bring a section into view, then say what is wrong with it.
  ///
  /// Awaited so the message lands once the field is actually on screen —
  /// a toast over a form still scrolling reads as being about something else.
  Future<void> _pointAt(GlobalKey key, String message) async {
    final target = key.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1, // just below the top, not jammed against it
      );
    }
    if (mounted) AppToast.info(context, message);
  }
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _locationController = TextEditingController();
  final _workersNeededController = TextEditingController(text: '1');
  
  String? _selectedCategory;

  /// The real database id of the chosen category.
  ///
  /// This used to be guessed as `indexOf(category) + 1` against a hardcoded
  /// list, which only matched the real ids by coincidence — adding, removing or
  /// reordering a category would have filed every new job under the wrong one.
  int? _selectedCategoryId;

  String? _customCategoryName; // used when 'Other' is selected

  /// Structured location chosen from the picker — carries the PSGC id and
  /// coordinates, unlike the display string in _locationController.
  LocationModel? _selectedLocation;

  /// Exact pin, if the employer dropped one. Overrides the barangay/city
  /// centroid so "3 km away" reflects the actual site rather than the middle
  /// of the barangay.
  double? _pinnedLat;
  double? _pinnedLng;
  String _salaryType = 'Daily';
  final List<String> _selectedSkills = [];
  final _customSkillController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isUrgent = false;
  bool _isNegotiable = false;
  bool _showPhotoError = false;

  // Schedule. _endDate stays null for a single-day job rather than being set
  // equal to _startDate, so the two states remain distinguishable server-side.
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  bool _showScheduleError = false;
  bool _isLoadingSkills = false;
  bool _showPinError = false;

  // Categories
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Plumbing', 'icon': Icons.plumbing},
    {'name': 'Electrical', 'icon': Icons.electrical_services},
    {'name': 'Painting', 'icon': Icons.format_paint},
    {'name': 'Carpentry', 'icon': Icons.carpenter},
    {'name': 'Construction', 'icon': Icons.construction},
    {'name': 'HVAC', 'icon': Icons.ac_unit},
    {'name': 'Landscaping', 'icon': Icons.grass},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services},
    {'name': 'Roofing', 'icon': Icons.roofing},
    {'name': 'Flooring', 'icon': Icons.layers},
    {'name': 'Automotive', 'icon': Icons.car_repair},
    {'name': 'Appliance Repair', 'icon': Icons.kitchen},
    {'name': 'Security', 'icon': Icons.security},
    {'name': 'Moving', 'icon': Icons.local_shipping},
    {'name': 'Pest Control', 'icon': Icons.bug_report},
    {'name': 'Pool Services', 'icon': Icons.pool},
    {'name': 'Delivery', 'icon': Icons.delivery_dining},
    {'name': 'Other', 'icon': Icons.build},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _budgetMaxController.dispose();
    _locationController.dispose();
    _workersNeededController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  /// Salary must parse to a real, positive number. The server also enforces
  /// `numeric|min:0`, but catching it here gives inline feedback instead of a
  /// 422 after the user has filled in the whole form.
  String? _validateSalary(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Required';

    final amount = double.tryParse(raw.replaceAll(',', ''));
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Salary must be greater than 0';
    if (amount > 1000000) return 'Amount looks too high';

    return null;
  }

  /*
      The top of the range. Optional - a single figure is a valid way to price
      a job - but when given it has to sit above the minimum.

      Checked here as well as on the server. The server has always refused an
      inverted range, so the post simply failed at submit with the reason
      arriving as a toast after the round trip; catching it on the field says
      which box is wrong, before the request.
  */
  String? _validateSalaryMax(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final amount = double.tryParse(raw.replaceAll(',', ''));
    if (amount == null) return 'Enter a valid amount';
    if (amount <= 0) return 'Must be greater than 0';
    if (amount > 1000000) return 'Amount looks too high';

    final min = double.tryParse(_budgetController.text.replaceAll(',', ''));
    if (min != null && amount < min) return 'Cannot be below the minimum';

    return null;
  }

  /// Skills for the chosen category, loaded from /skills?category_id= — the
  /// same endpoint worker onboarding uses, so a job's required skills and a
  /// worker's skills are drawn from one list and can actually be matched.
  List<String> get _availableSkills {
    if (_selectedCategoryId == null) return [];
    return context
        .read<WorkerProfileProvider>()
        .availableSkills
        .map((s) => s.name)
        .toList();
  }

  /// Icon for a server-supplied category name. Falls back to a generic icon so
  /// a category added later (including a worker's custom one) still renders.
  IconData _iconForCategory(String name) {
    final match = _categories.firstWhere(
      (c) => (c['name'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => const {'icon': Icons.category},
    );
    return match['icon'] as IconData;
  }

  /// Resolves the chosen skill names back to their database ids for the API.
  List<int> get _selectedSkillIds {
    final all = context.read<WorkerProfileProvider>().availableSkills;
    return all
        .where((s) => _selectedSkills.contains(s.name))
        .map((s) => s.id)
        .toList();
  }

  /// Selects a category and loads its skills from the API.
  ///
  /// [categoryId] is the real database id, resolved from the categories the
  /// server returned — not inferred from a list position.
  Future<void> _updateSkillsForCategory(String? category, {int? categoryId}) async {
    setState(() {
      _selectedSkills.clear();
      _selectedCategory = category;
      _selectedCategoryId = categoryId;
      _isLoadingSkills = categoryId != null;
      if (category != 'Other') _customCategoryName = null;
    });

    if (categoryId == null) return;

    // Awaited, then setState — _availableSkills reads the provider with
    // context.read, which does not rebuild on notifyListeners. Without this
    // the skills arrived but never painted, and only appeared after picking a
    // different category forced a rebuild — showing the *previous*
    // category's skills.
    await context.read<WorkerProfileProvider>().fetchSkillsByCategory(categoryId);

    if (!mounted) return;
    // The user may have moved on while this was in flight.
    if (_selectedCategoryId != categoryId) return;

    setState(() => _isLoadingSkills = false);
  }

  void _handleUrgentToggle() {
    if (!_isUrgent) {
      // Show popup when enabling urgent
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flash_on, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Mark as Urgent?'),
            ],
          ),
          content: const Text(
            'Urgent jobs get priority placement and appear at the top of search results, helping you find workers faster.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isUrgent = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: const Text('Mark as Urgent'),
            ),
          ],
        ),
      );
    } else {
      // Just toggle off without popup
      setState(() => _isUrgent = false);
    }
  }

  /// What the server accepts — mirrored here so a photo is refused while the
  /// gallery is still open, rather than after a long upload.
  static const _allowedPhotoTypes = {'jpg', 'jpeg', 'png'};
  static const int _maxPhotoBytes = 5 * 1024 * 1024; // matches max:5120
  static const int _maxPhotos = 4;

  /*
      What the whole request may weigh.

      nginx refuses a body over 1MB on this server — 1024KB answers, 1100KB
      returns 413 — and that ceiling applies to the request, not to each
      photo. Laravel's own rule is a generous 5MB per file, so validation
      would happily pass a set the server never reads.

      Leaving 100KB for the form fields and the multipart boundaries, which
      is far more than they need.
  */
  static const int _maxTotalUploadBytes = 900 * 1024;

  /*
      Checked here, because the alternative is a failed upload.

      The picker took anything the gallery offered and silently dropped
      whatever went past four. Two ways that went wrong:

      A screenshot or a photo straight off an iPhone is not a jpg — it is a
      png at 12MB, or an heic. The server takes jpg, jpeg and png at 5MB, so
      those were refused only after the whole file had been uploaded, and a
      file large enough to trip nginx's own limit came back as an HTML error
      page rather than a message the app could read.

      And silently discarding the fifth photo meant someone picked six, saw
      four, and had no idea which two were missing or why.
  */
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();

    /*
        The gallery does the limiting, not us.

        This called pickMultiImage() bare, so you could select a hundred
        photos, watch the picker accept all of them, and then find four on the
        form. Filtering after the fact is the wrong place: the cap belongs
        where the choosing happens, and `limit` makes the gallery itself stop
        offering a fifth once four are ticked.

        The size arguments matter just as much and were also missing. Every
        other picker in this app compresses — the verification one carries the
        comment "Reduced from 1920 to prevent large files" — and job photos
        were the only place still sending whatever the camera produced. Four
        full-resolution photos is tens of megabytes in one multipart POST,
        which the server refuses outright, and the refusal is an HTML page the
        app can only report as "something went wrong".

        1600px at quality 85 is still sharp enough to judge a job by, and
        turns those tens of megabytes into a couple.
    */
    final int room = _maxPhotos - _selectedImages.length;
    if (room <= 0) {
      AppToast.info(context, 'You can add up to $_maxPhotos photos.');
      return;
    }

    /*
        `limit` throws below 2.

        image_picker_android asserts limit >= 2 and raises an ArgumentError
        otherwise, so passing the literal room left — 1, when three photos are
        already chosen — would crash on opening the gallery rather than
        capping it. Ask for 2 in that case and drop the extra afterwards,
        which is the one place trimming is still correct.
    */
    /*
        Sized to what the server will actually accept.

        Measured rather than assumed: posting a 1024KB body to /api/v1/jobs
        returns 401, and 1100KB returns 413, so nginx is sitting on its
        default client_max_body_size of 1MB. That is the whole multipart
        body — four photos, every form field and the boundaries — not a
        per-file limit.

        1600px at quality 85 is roughly 250-450KB a photo, so four of them
        cleared a megabyte on their own and the post failed with the server
        refusing to read it. 1200px at 75 lands around 120-180KB, which keeps
        four inside the budget with room for the rest of the form.

        Still plenty for a job photo on a phone. The real fix is
        client_max_body_size on the server; until that changes this is what
        fits.
    */
    final List<XFile> images = await picker.pickMultiImage(
      limit: room < 2 ? 2 : room,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (images.isEmpty || !mounted) return;

    final accepted = <File>[];
    var wrongType = 0;
    var tooBig = 0;

    for (final xfile in images) {
      final ext = xfile.path.split('.').last.toLowerCase();
      if (!_allowedPhotoTypes.contains(ext)) {
        wrongType++;
        continue;
      }
      final file = File(xfile.path);
      if (await file.length() > _maxPhotoBytes) {
        tooBig++;
        continue;
      }
      accepted.add(file);
    }

    if (!mounted) return;

    setState(() {
      // The picker caps the selection, so this only ever trims the single
      // extra the `limit >= 2` floor above can let through.
      _selectedImages.addAll(accepted.take(room));
      if (_selectedImages.isNotEmpty) _showPhotoError = false;
    });

    // Type and size are still worth checking. Resizing makes an oversized
    // file unlikely rather than impossible, and a gallery can hold formats
    // the server will not take.
    final problems = <String>[
      if (wrongType > 0) '$wrongType not a JPG or PNG',
      if (tooBig > 0) '$tooBig still over 5MB',
    ];

    if (problems.isEmpty) return;

    final skipped = wrongType + tooBig;
    AppToast.warning(
      context,
      '$skipped photo${skipped == 1 ? '' : 's'} not added: '
      '${problems.join(', ')}.',
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// True once the user has typed or picked anything — an empty form can be
  /// left without a warning.
  bool get _hasUnsavedInput =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _budgetController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _selectedCategory != null ||
      _selectedSkills.isNotEmpty ||
      _selectedImages.isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedInput) return true;
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard This Job Post?'),
            content: const Text(
              'You have unsaved changes. If you leave now, everything you\'ve entered will be discarded.',
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
        ) ??
        false;
    return shouldExit;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _confirmDiscard();
        if (shouldExit && mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text(
          'Post a Job',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final shouldExit = await _confirmDiscard();
            if (shouldExit && mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Basic Information
              _buildSection(
                title: 'Basic Information',
                anchor: _basicsKey,
                icon: Icons.work_outline,
                children: [
                  _buildLabel('Job Title'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(icon: Icons.work_outline),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel('Job Category'),
                  const SizedBox(height: 8),
                  _buildCategorySelector(),

                  // Custom category name — only when "Other" selected
                  if (_selectedCategory == 'Other') ...[
                    const SizedBox(height: 12),
                    _buildLabel('Specify Category'),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _customCategoryName,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (v) => setState(() => _customCategoryName = v.trim()),
                      decoration: _inputDecoration(icon: Icons.edit_outlined),
                      validator: (v) =>
                          _selectedCategory == 'Other' && (v?.isEmpty ?? true)
                              ? 'Please specify the category'
                              : null,
                    ),
                  ],

                  const SizedBox(height: 16),
                  
                  _buildLabel('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: _inputDecoration(
                      hint: 'Describe the work in detail...',
                      icon: Icons.description,
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  
                  // Shown while the category's skills are in flight, so the
                  // section is never just silently missing.
                  if (_isLoadingSkills) ...[
                    const SizedBox(height: 16),
                    _buildLabel('Required Skills'),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Loading skills…',
                            style: TextStyle(
                                fontSize: 13.5, color: AppColors.neutral600)),
                      ],
                    ),
                  ] else if (_selectedCategory != null &&
                      _availableSkills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLabel('Required Skills'),
                    const SizedBox(height: 8),
                    _buildSkillChips(),
                    const SizedBox(height: 10),
                    _buildCustomSkillInput(),
                  ] else if (_selectedCategory != null) ...[
                    // Category chosen but the list came back empty ("Other",
                    // or a category with no seeded skills) — let them type
                    // their own rather than leaving a dead end.
                    const SizedBox(height: 16),
                    _buildLabel('Required Skills'),
                    const SizedBox(height: 8),
                    _buildCustomSkillInput(),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Job Photos
              _buildSection(
                title: 'Job Photos',
                anchor: _photosKey,
                subtitle: 'Add at least 1 photo (up to 4)',
                icon: Icons.photo_camera_outlined,
                children: [
                  _buildPhotoSelector(),
                  if (_showPhotoError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'At least one photo is required',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Workers Needed
              _buildSection(
                title: 'Workers Needed',
                icon: Icons.groups_outlined,
                children: [
                  TextFormField(
                    controller: _workersNeededController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(icon: Icons.people),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final number = int.tryParse(value!);
                      if (number == null || number < 1) return 'Must be at least 1';
                      if (number > 9) return 'Maximum 9 workers';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Salary & Location
              _buildSection(
                title: 'Salary & Location',
                anchor: _locationKey,
                icon: Icons.payments_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Salary from'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                hint: '1,200',
                                prefix: '₱ ',
                              ),
                              // Previously only checked "not empty", so "abc"
                              // passed here and then silently became null at
                              // double.tryParse, posting a job with no salary.
                              validator: _validateSalary,
                              // Re-run the maximum's check, so correcting the
                              // minimum clears an error sitting on the other
                              // box rather than leaving it stale.
                              onChanged: (_) {
                                if (_budgetMaxController.text.trim().isNotEmpty) {
                                  _formKey.currentState?.validate();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      /*
                          The top of the range.

                          The server has accepted budget_max from the start and
                          the whole salary filter is built on a range, but no
                          field ever collected one - so every job was posted
                          with a single figure and "₱500-800/day" could not be
                          expressed. Optional, because pricing a job at one
                          number is legitimate.
                      */
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('to (optional)'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _budgetMaxController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(
                                hint: '1,800',
                                prefix: '₱ ',
                              ),
                              validator: _validateSalaryMax,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  /*
                      Payment on its own line.

                      This shared a row with the two salary fields, so on a
                      360px phone each of the three had about 88 pixels: a
                      money field with a peso prefix showed roughly "1,2..."
                      and the dropdown had no room for its own value. Three
                      inputs across a phone is the cramping, and no amount of
                      vertical spacing was going to fix it.

                      The range belongs together and the period does not, so
                      the split follows the meaning as well as the width.
                  */
                  _buildLabel('Payment'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _salaryType,
                    items: const ['Daily', 'Hourly', 'Project'],
                    onChanged: (value) => setState(() => _salaryType = value!),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel('Location'),
                  const SizedBox(height: 8),
                  // Picker rather than free text, so every job stores a real
                  // location_id and coordinates — needed for "jobs near you"
                  // and for location filtering to match reliably.
                  LocationPickerField(
                    controller: _locationController,
                    labelText: '',
                    hintText: 'Search barangay, city or municipality',
                    fillColor: AppColors.surfaceVariant,
                    // Profile prefills and pin reconciliation set this
                    // directly; without it the field would treat them as
                    // typed text and reject a place we chose ourselves.
                    selection: _selectedLocation,
                    onSelected: (location) => setState(() {
                      _selectedLocation = location;
                      // A new place invalidates any pin dropped for the old one.
                      _pinnedLat = null;
                      _pinnedLng = null;
                    }),
                    // Text edited after choosing — drop the stale id and pin
                    // rather than saving them against a different label.
                    onCleared: () => setState(() {
                      _selectedLocation = null;
                      _pinnedLat = null;
                      _pinnedLng = null;
                    }),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  /*
                      The "using your profile location" note is gone.

                      It explained why the field was already filled in, which
                      is not a question anyone was asking: a field with a
                      value in it and a cursor you can put in it needs no note
                      saying it can be changed. It was a sentence and an icon
                      spent on the least surprising thing on the screen.
                  */
                  const SizedBox(height: 12),
                  _buildPinRow(),
                ],
              ),
              const SizedBox(height: 16),

              // Schedule
              _buildSection(
                title: 'Schedule',
                anchor: _scheduleKey,
                icon: Icons.event_outlined,
                children: [_buildScheduleFields()],
              ),
              const SizedBox(height: 16),

              // Job Priority
              _buildSection(
                title: 'Job Priority (Optional)',
                icon: Icons.flash_on_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton(
                          label: 'Urgent',
                          icon: Icons.flash_on,
                          isActive: _isUrgent,
                          onTap: _handleUrgentToggle,
                          color: AppColors.accent,
                          showWarning: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToggleButton(
                          label: 'Negotiable',
                          icon: Icons.handshake,
                          isActive: _isNegotiable,
                          onTap: () => setState(() => _isNegotiable = !_isNegotiable),
                          color: AppColors.success,
                          showWarning: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ── Schedule ────────────────────────────────────────────────────────────────

  /// Start date, an optional end date, and an optional time.
  ///
  /// The start date is required by the server. Without dates on jobs, being
  /// hired once has to cancel every other application a worker has, because
  /// there is no way to tell which of them actually collide.
  ///
  /// The end date is behind a toggle rather than always visible: most of this
  /// work is a single day, and two date fields side by side invites people to
  /// fill both in when only the first is meaningful.
  Widget _buildScheduleFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateField(
          label: 'Start date *',
          value: _startDate,
          hint: 'Select date',
          onTap: _pickStartDate,
          isError: _showScheduleError,
        ),
        if (_showScheduleError) ...[
          const SizedBox(height: 6),
          const Text(
            'Please choose when the work starts.',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
        /*
            No toggle, just an optional second date.

            There used to be a switch labelled "Runs over several days" with a
            line under it explaining which way it was currently set, and the
            end date only appeared once it was on. That is three things to
            read and one thing to operate in order to answer a question the
            end date field asks by itself: leave it empty and the job is one
            day, fill it in and it is not.

            The switch also had to be kept in step with the date - turning it
            off had to clear a date that was already chosen - which is state
            that now cannot disagree because there is only one piece of it.
        */
        const SizedBox(height: 12),
        _buildDateField(
          label: 'End date (optional)',
          value: _endDate,
          hint: 'Same day',
          onTap: _startDate == null ? null : _pickEndDate,
          onClear: _endDate == null
              ? null
              : () => setState(() => _endDate = null),
        ),
        const SizedBox(height: 12),
        _buildDateField(
          label: 'Start time (optional)',
          value: null,
          display: _startTime?.format(context),
          hint: 'Select time',
          icon: Icons.schedule_outlined,
          onTap: _pickStartTime,
          onClear: _startTime == null
              ? null
              : () => setState(() => _startTime = null),
        ),

        /*
            What the worker will actually see.

            Three separate controls produce one line of text on the job card,
            and until you posted the job there was no way to know what that line
            would say. Showing it here closes the loop — and it is built by the
            same rules as Job.scheduleLabel, so the form and the card cannot
            describe the same dates differently.
        */
        if (_startDate != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Workers will see: ${_schedulePreview()}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Mirrors Job.scheduleLabel — same collapsing of a same-month range, same
  /// handling of an absent end date and time.
  String _schedulePreview() {
    final start = _startDate!;
    final end = _endDate;

    String short(DateTime d) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
    }

    if (end != null &&
        !(end.year == start.year &&
            end.month == start.month &&
            end.day == start.day)) {
      return end.year == start.year && end.month == start.month
          ? '${short(start)} – ${end.day}'
          : '${short(start)} – ${short(end)}';
    }

    final time = _startTime?.format(context);
    return time == null ? short(start) : '${short(start)}, $time';
  }

  /// One tappable row, used for all three fields so they read as a set.
  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required String hint,
    required VoidCallback? onTap,
    String? display,
    IconData icon = Icons.calendar_today_outlined,
    bool isError = false,
    VoidCallback? onClear,
  }) {
    final shown = display ?? (value == null ? null : _formatDate(value));
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? AppColors.neutral100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? AppColors.error
                : (shown != null ? AppColors.primary : AppColors.neutral300),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: shown != null
                    ? AppColors.primary
                    : AppColors.neutral500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shown ?? hint,
                    // Overflow guard: a long formatted date on a narrow phone
                    // is exactly the kind of row that reports a RenderFlex
                    // overflow on one device and not another.
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          shown != null ? FontWeight.w600 : FontWeight.w400,
                      color: shown != null
                          ? AppColors.neutral900
                          : AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.neutral500,
                onPressed: onClear,
                tooltip: 'Clear',
              )
            else if (!disabled)
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      // Today, not tomorrow. Same-day hiring is the normal case for this kind
      // of work — a burst pipe does not wait until tomorrow — and the server
      // uses after_or_equal:today for the same reason.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      _startDate = picked;
      _showScheduleError = false;
      // An end date that now sits before the start would be rejected by the
      // server. Dropping it here turns a validation error into a field the
      // employer simply picks again.
      if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
    });
  }

  Future<void> _pickEndDate() async {
    final start = _startDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? start,
      firstDate: start,
      lastDate: start.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  /// 24-hour `HH:mm`, which is the only shape the server's `date_format:H:i`
  /// rule accepts. `TimeOfDay.format` follows the phone's locale and would send
  /// "8:00 AM" on a device set to 12-hour time.
  String? get _startTimeForApi => _startTime == null
      ? null
      : '${_startTime!.hour.toString().padLeft(2, '0')}:'
          '${_startTime!.minute.toString().padLeft(2, '0')}';

  Widget _buildSection({
    required String title,
    String? subtitle,
    IconData? icon,
    required List<Widget> children,
    // Set on the sections _submitJob can refuse, so it can scroll to them.
    Key? anchor,
  }) {
    return Container(
      key: anchor,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: icon != null ? 44 : 0),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.neutral600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Exact-pin row under the location picker.
  ///
  /// Required: a barangay centroid puts every job in that barangay on the same
  /// point, so workers can't tell which end of it a site is on. The pin is
  /// what makes the distance reflect the actual job.
  /*
      The same small pin control the profile and setup flow use.

      This was a full width card - fill, border, icon, title, a sentence and
      a chevron - to offer one action. All four pin controls in the app now
      look the same, because they do the same thing to the same kind of data
      and looking different was only ever going to make someone wonder
      whether they did.
  */
  Widget _buildPinRow() {
    final hasPin = _pinnedLat != null && _pinnedLng != null;
    final canPin = _selectedLocation != null;

    if (hasPin) return _buildPinPreview();

    final tint = !canPin
        ? AppColors.neutral400
        : (_showPinError ? AppColors.error : AppColors.primary);

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: canPin ? _openPinPicker : null,
        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
        label: const Text('Pin location'),
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
    );
  }
  Widget _buildPinPreview() {
    final point = LatLng(_pinnedLat!, _pinnedLng!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 16,
                    // Preview only — panning happens in the picker.
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'ph.kaya.app',
                      // See pin_location_screen: maxZoom alone blanks the map
                      // past z19 because the camera keeps going after the tiles
                      // stop. maxNativeZoom upscales instead.
                      maxNativeZoom: 19,
                      maxZoom: 21,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_pin,
                              size: 40, color: AppColors.error),
                        ),
                      ],
                    ),
                  ],
                ),
                // Whole-surface tap target to reopen the picker.
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: _openPinPicker),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.where_to_vote, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Exact location pinned',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900)),
            ),
            TextButton(
              onPressed: _openPinPicker,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Change',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 14),
            TextButton(
              onPressed: () => setState(() {
                _pinnedLat = null;
                _pinnedLng = null;
              }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Remove',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPinPicker() async {
    final result = await Navigator.pushNamed(
      context,
      '/pin-location',
      arguments: {
        // Open on the chosen place rather than making the user pan there.
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

    // The pin is the more precise truth, so when it lands somewhere other than
    // the chosen place the two must be reconciled — otherwise the job reads
    // "Urdaneta City" while sitting in Binalonan and nothing flags it.
    final movedElsewhere = resolved != null &&
        _selectedLocation != null &&
        !isSamePlace(resolved, _selectedLocation!);

    if (movedElsewhere) {
      final useResolved = await _confirmLocationChange(resolved);
      if (!mounted) return;

      if (useResolved) {
        setState(() {
          // Only the location — the picker writes its own label from this.
          // Setting controller.text here fired the field's listener before it
          // could see the new selection, which wiped it straight back out.
          _selectedLocation = resolved;
          _pinnedLat = lat;
          _pinnedLng = lng;
          _showPinError = false;
        });
      }
      // Declined: drop the pin rather than keep one that contradicts the label.
      return;
    }

    setState(() {
      _pinnedLat = lat;
      _pinnedLng = lng;
    });
  }

  /// Asked only when the pin disagrees with the chosen place. Keeping both
  /// would be the bug; this makes the user pick which one is right.
  Future<bool> _confirmLocationChange(LocationModel resolved) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pin is somewhere else'),
            content: Text(
              'Your pin is in ${resolved.displayName}, not '
              '${_selectedLocation?.displayName ?? 'the selected location'}.\n\n'
              'Use the pinned location instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard pin'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('Use pinned'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /*
      Air above every label, in one place.

      The form was built almost entirely out of one number. Section to
      section, header to first field, field to next field — all 16, against
      the 8 that ties a label to its own input. Nothing in that is a bigger
      break than anything else, so seven cards of inputs read as a single
      unbroken vertical column with no grouping to follow.

      This was 6 first, which is what a form looks like when someone is
      nervous about changing it: 8 against 22 is a real ratio on paper and
      invisible on a phone. 16 makes the break between one question and the
      next 30 pixels against the 8 inside a pair — about four to one, and
      actually legible as grouping.

      One place rather than fourteen call sites, so the rhythm cannot drift
      apart again field by field.
  */
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral900,
        ),
      ),
    );
  }

  /// [hint] is optional on purpose.
  ///
  /// Every field here already has a visible label above it, so a hint that
  /// just restates the label with an example is noise the user has to read
  /// past. Pass one only when it teaches something the label can't — a format,
  /// a unit, or what to search by.
  InputDecoration _inputDecoration({
    String? hint,
    IconData? icon,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.neutral400,
        fontSize: 15,
      ),
      prefixText: prefix,
      prefixStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.neutral900,
      ),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.neutral500, size: 20) : null,
      filled: true,
      fillColor: AppColors.neutral50,
      // 14 put the text almost against the top and bottom of its own box on a
      // form this long, which is most of what made it feel packed. 16 is also
      // closer to a comfortable touch target on a small phone.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neutral300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neutral300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      // Fixed height matches the adjacent salary TextFormField's rendered
      // height (contentPadding vertical 14 + border) — without this the two
      // side-by-side fields sat at slightly different heights.
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral300),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.neutral600),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.neutral900,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedCategory != null ? AppColors.primary : AppColors.neutral300,
            width: _selectedCategory != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_selectedCategory != null)
              Icon(
                _categories.firstWhere((c) => c['name'] == _selectedCategory)['icon'],
                color: AppColors.primary,
                size: 20,
              )
            else
              Icon(Icons.category, color: AppColors.neutral400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedCategory ?? 'Select job category',
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedCategory != null ? AppColors.neutral900 : AppColors.neutral400,
                  fontWeight: _selectedCategory != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.neutral600),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Job Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 16),
            // Categories come from the server, not a hardcoded array — the same
            // list workers pick from during onboarding.
            Expanded(
              child: Consumer<WorkerProfileProvider>(
                builder: (context, taxonomy, _) {
                  final categories = taxonomy.categories;

                  if (categories.isEmpty) {
                    return Center(
                      child: taxonomy.isLoading
                          ? const CircularProgressIndicator()
                          : const Text('No categories available'),
                    );
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategoryId == category.id;
                      return ListTile(
                        leading: Icon(
                          _iconForCategory(category.name),
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.neutral600,
                        ),
                        title: Text(
                          category.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.neutral900,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () {
                          _updateSkillsForCategory(
                            category.name,
                            categoryId: category.id,
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSkills.map((skill) {
        final isSelected = _selectedSkills.contains(skill);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedSkills.remove(skill);
              } else {
                _selectedSkills.add(skill);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.neutral300,
              ),
            ),
            child: Text(
              skill,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.neutral700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomSkillInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Already added custom skills
        if (_selectedSkills.where((s) => !_availableSkills.contains(s)).isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedSkills
                .where((s) => !_availableSkills.contains(s))
                .map((skill) => Chip(
                      label: Text(skill, style: const TextStyle(fontSize: 13.5)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      deleteIconColor: AppColors.primary,
                      onDeleted: () => setState(() => _selectedSkills.remove(skill)),
                    ))
                .toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSkillController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hint: 'Add a custom skill...',
                  icon: Icons.add_circle_outline,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                final skill = _customSkillController.text.trim();
                if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
                  setState(() {
                    _selectedSkills.add(skill);
                    _customSkillController.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoSelector() {
    return SizedBox(
      height: 100,
      // A Row here would overflow off-screen once 3-4 photos are picked on
      // narrower phones — nothing scrolled, it just clipped/errored.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // Existing photos
          ...List.generate(_selectedImages.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _selectedImages[index],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // Add photo button
          if (_selectedImages.length < 4)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.neutral300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: AppColors.neutral500, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    required bool showWarning,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: showWarning
          ? () {
              AppToast.warning(context,
                  'Only mark a job urgent if it really is. Accounts that misuse this get flagged.');
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : AppColors.neutral300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.neutral600,
              size: 18,
            ),
            const SizedBox(width: 8),
            /*
                Wrapped, not truncated.

                Two of these share a row, so each gets half the width, and on
                a narrow phone at a large font size "Negotiable" was about a
                pixel wider than its half. It was ellipsised to fit, which
                turned the label into "Negoti…" — a control that no longer
                says what it does.

                Losing the end of a two-word label is worse than the button
                being a line taller, so it wraps now. Ellipsis stays as the
                last resort for a second line that still does not fit.
            */
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.neutral600,
                ),
              ),
            ),
            if (showWarning) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.error_outline,
                color: isActive ? Colors.white : AppColors.warning,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.neutral200),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.neutral300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post Job',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitJob() async {
    /*
        A refusal now arrives with the field it is refusing.

        Every branch below used to fire a toast and stop, leaving the employer
        on whatever part of the form they happened to be looking at. On a form
        this long the field being complained about was usually somewhere off
        screen, so the toast named a problem they then had to go hunting for.

        The form's own validate() runs first and marks its fields red, but it
        does not move to them either — so when it fails, go to the top, where
        the title and category live, rather than leaving them staring at the
        bottom of the page.
    */
    if (!_formKey.currentState!.validate()) {
      await _pointAt(_basicsKey, 'Please fill in the highlighted fields');
      return;
    }

    if (_selectedCategory == null || _selectedCategoryId == null) {
      await _pointAt(_basicsKey, 'Please select a category');
      return;
    }

    if (_selectedImages.isEmpty) {
      setState(() => _showPhotoError = true);
      await _pointAt(_photosKey, 'Please add at least one photo of the job');
      return;
    }

    // The picker's own validator covers this, but a job with no location_id
    // saves with no coordinates — invisible in "jobs near you", no distance,
    // no proximity score. Worth a second gate rather than a silent bad row.
    if (_selectedLocation == null) {
      await _pointAt(
          _locationKey, 'Please pick the job location from the suggestions');
      return;
    }

    if (_pinnedLat == null || _pinnedLng == null) {
      setState(() => _showPinError = true);
      await _pointAt(
          _locationKey, 'Please pin the exact job location on the map');
      return;
    }

    // Caught here as well as server-side so the employer sees the field turn
    // red rather than a toast about a form they have already scrolled past.
    if (_startDate == null) {
      setState(() => _showScheduleError = true);
      await _pointAt(_scheduleKey, 'Please choose when the work starts');
      return;
    }

    /*
        Weighed before it is sent.

        Without this the only thing that notices an over-sized set is nginx,
        which answers 413 after the whole upload has gone over a phone
        connection — so the employer waits through it and is told it failed
        at the end. Resizing on pick makes this unlikely rather than
        impossible: four detailed photos can still add up.

        Checked here rather than at pick time because it is the total that
        matters, and the total is only known once they have finished choosing.
    */
    var totalBytes = 0;
    for (final photo in _selectedImages) {
      totalBytes += await photo.length();
    }
    if (!mounted) return;

    if (totalBytes > _maxTotalUploadBytes) {
      await _pointAt(
        _photosKey,
        'Those photos add up to ${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB, '
        'which is more than the server accepts. Remove one and try again.',
      );
      return;
    }

    {

      setState(() => _isLoading = true);

      final categoryId = _selectedCategoryId!;
      final jobProvider = context.read<JobProvider>();
      final success = await jobProvider.createJob(
        title:       _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId:  categoryId,
        // Real skill ids, so a job's requirements can be matched against the
        // skills workers picked during onboarding.
        skillIds:    _selectedSkillIds,
        budgetMin:   double.tryParse(_budgetController.text.replaceAll(',', '')),
        // Optional upper bound. createJob has always accepted it; nothing ever
        // sent one, so every job was filed with a single figure.
        budgetMax:   double.tryParse(_budgetMaxController.text.replaceAll(',', '')),
        location:    _locationController.text.trim(),
        // Structured location from the picker: the id normalizes filtering and
        // the coordinates power proximity search.
        locationId:  _selectedLocation?.id,
        // A dropped pin beats the barangay/city centroid. When absent the
        // centroid is used, which is what makes pinning optional.
        latitude:    _pinnedLat ?? _selectedLocation?.latitude,
        longitude:   _pinnedLng ?? _selectedLocation?.longitude,
        city:        _selectedLocation?.displayName,
        isUrgent:    _isUrgent,
        isNegotiable: _isNegotiable,
        // The Daily/Hourly/Project picker used to be decorative — nothing
        // stored it and job details hardcoded "/ project".
        budgetPeriod: _salaryType.toLowerCase(),
        photos:      _selectedImages,
        startDate:   _startDate!,
        // Only sent when the employer said the job runs over several days, so
        // turning the toggle off cannot leave a stale end date on the record.
        endDate:     _endDate,
        startTime:   _startTimeForApi,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      if (success) {
        AppToast.success(context, 'Job posted successfully!');
        Navigator.pop(context);
      } else {
        AppToast.error(context, jobProvider.errorMessage ?? 'Failed to post job');
      }
    }
  }
}
