import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/employer_type.dart';
import '../../../providers/employer_profile_provider.dart';
import '../../../shared/widgets/location_picker_field.dart';

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

  bool _isLoading = false;
  bool _initialized = false;
  bool get _hasChanges =>
      _nameController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty;

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
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Company/Individual Name ──
                  _fieldLabel('Company / Business Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDeco(
                      hint: 'e.g. ABC Construction Corp',
                      icon: Icons.business,
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
                    maxLines: 6,
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
                    onSelected: (_) => setState(() {}),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Password change — coming soon')),
                      );
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
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            success ? 'Profile updated' : provider.errorMessage ?? 'Update failed'),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );

    if (success) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
      });
    }
  }
}
