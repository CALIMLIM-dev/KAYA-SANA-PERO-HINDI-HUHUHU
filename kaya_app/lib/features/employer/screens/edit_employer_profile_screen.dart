import 'package:flutter/material.dart';
import '../../profile/widgets/change_password_sheet.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/employer_type.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';
import '../../../core/widgets/app_toast.dart';

/// Edit Employer Profile Screen
/// Pre-filled with existing data, each field is editable
/// Arguments: { name, description, location, role }
class EditEmployerProfileScreen extends StatefulWidget {
  const EditEmployerProfileScreen({super.key});

  @override
  State<EditEmployerProfileScreen> createState() =>
      _EditEmployerProfileScreenState();
}

class _EditEmployerProfileScreenState
    extends State<EditEmployerProfileScreen> {
  final _nameController        = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController    = TextEditingController();

  /// The PSGC row behind the location field. Needed so a location change
  /// updates location_id too, not just the label.
  LocationModel? _selectedLocation;

  bool _isLoading = false;
  bool _initialized = false;

  /// What the form was loaded with, so "has changes" can mean what it says.
  String _initialName = '';
  String _initialDescription = '';
  String _initialLocation = '';

  /// This asked whether any field was *non-empty*, which on a form prefilled
  /// from an existing profile is true before the user touches anything. So Save
  /// was always live, and tapping it with no edits sent a pointless write.
  ///
  /// A changed location counts even when its label is identical: picking the
  /// same-named barangay in a different province changes the id and the
  /// coordinates while the text stays put.
  bool get _hasChanges =>
      _nameController.text.trim() != _initialName ||
      _descriptionController.text.trim() != _initialDescription ||
      _locationController.text.trim() != _initialLocation ||
      _selectedLocation != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      _nameController.text        = args?['name']        ?? '';
      _descriptionController.text = args?['description'] ?? '';
      _locationController.text    = args?['location']    ?? '';

      _initialName        = _nameController.text.trim();
      _initialDescription = _descriptionController.text.trim();
      _initialLocation    = _locationController.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    /*
        An individual employer has no company name.

        This field was labelled "Company / Business Name" for both
        types, prefilled with the account name for an individual, and
        then dropped on save - the server only stores company_name for
        a company. So it read as a way to rename yourself, said
        "Profile updated", and changed nothing. It now shows what it
        is: the account name, which is changed where it lives.
    */
    final isCompany = context.watch<EmployerProfileProvider>()
            .profile?.employerType ==
        EmployerType.company;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // The "Cancel" action that used to sit here is gone.
        //
        // It popped the route — exactly what the back arrow beside it already
        // does — so the app bar carried two controls for one job, and the
        // second was clipped at the edge. Deleting the clipped duplicate is a
        // better fix than finding room for it.
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Extra room at the bottom so the last row is not pressed
              // against the Save bar. Scrolled to the end, Verification used to
              // sit directly under the bar's shadow and read as being covered
              // by it.
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Company/Individual Name ──
                  _fieldLabel(
                      isCompany ? 'Company / Business Name' : 'Your name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    readOnly: !isCompany,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco(
                      hint: isCompany
                          ? 'e.g. ABC Construction Corp'
                          : 'Your account name',
                      icon: isCompany ? Icons.business : Icons.person,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Description ──
                  _fieldLabel('About Your Company'),
                  const SizedBox(height: 4),
                  const Text(
                    'Tell workers what your company does and what makes you a great employer',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.neutral500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    // Four, not six. At six this one box was a third of the
                    // screen, which is what pushed Verification down under the
                    // Save bar in the first place. It still scrolls for longer
                    // text; it just no longer reserves the room up front.
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco(
                      hint:
                          'Describe what your company does, your values, and what makes you a great employer...',
                      isMultiline: true,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Location ──
                  _fieldLabel('Location'),
                  const SizedBox(height: 8),
                  LocationPickerField(
                    controller: _locationController,
                    labelText: '',
                    hintText: 'Search city or municipality',
                    // An employer is matched on the city everywhere it
                    // matters, so a barangay here made two accounts in
                    // the same city look like different places. Setup
                    // was fixed and this screen was not, which left the
                    // rule undone the moment anyone edited a profile.
                    cityLevel: true,
                    // Every other field on this form is outlined; without this
                    // the location field was the one borderless control among
                    // them.
                    borderColor: AppColors.neutral300,
                    selection: _selectedLocation,
                    // Was `(_) => setState(() {})`, which threw the chosen
                    // place away and saved the label alone — leaving
                    // location_id pointing at the previous town, so distances
                    // and the job-post prefill used the wrong coordinates.
                    onSelected: (location) =>
                        setState(() => _selectedLocation = location),
                    onCleared: () => setState(() => _selectedLocation = null),
                  ),

                  const SizedBox(height: 28),

                  // ── Divider ──
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Change password link ──
                  _menuItem(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onTap: () {
                      // Was "coming soon" for a form that has been finished and
                      // wired to PUT /me/password the whole time — it just
                      // lived inside the settings screen and nothing else
                      // could reach it.
                      showChangePasswordSheet(context);
                    },
                  ),

                  const SizedBox(height: 8),

                  // ── Verification link ──
                  _menuItem(
                    icon: Icons.verified_outlined,
                    label: 'Verification',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Not Verified',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning)),
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/verification',
                      arguments: {
                        'type': 'business_reg',
                        'title': 'Business Registration',
                        'subtitle':
                            'Upload DTI, SEC, or Mayor\'s permit',
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Save Button ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _hasChanges && !_isLoading ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    disabledForegroundColor: AppColors.neutral500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900));
  }

  InputDecoration _inputDeco(
      {required String hint, IconData? icon, bool isMultiline = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.neutral400, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.neutral500, size: 20)
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMultiline ? 14 : 14,
      ),
      alignLabelWithHint: isMultiline,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutral300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.neutral600),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral900)),
            ),
            trailing ??
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    final provider = context.read<EmployerProfileProvider>();
    final isCompany =
        provider.profile?.employerType == EmployerType.company;

    // Previously this faked an 800ms delay and reported "Profile updated"
    // without sending anything — the edit was silently discarded.
    final success = await provider.updateProfile(
      // For a company the name field is the company name; for an individual the
      // employer profile has no name of its own (it comes from the user record).
      companyName: isCompany ? _nameController.text.trim() : null,
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      // Only sent when the user actually picked a new place — omitting them
      // leaves the stored values alone rather than nulling them, so editing
      // just the description can't wipe the coordinates.
      locationId: _selectedLocation?.id,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    AppToast.info(context, success ? 'Profile updated' : provider.errorMessage ?? 'Update failed');

    if (success) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
      });
    }
  }
}
