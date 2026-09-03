import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/worker_profile_provider.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/skill_model.dart';
import '../../../core/widgets/app_toast.dart';

/*
    Picking skills, during setup and afterwards alike.

    There used to be a `draftOnly` flag that setup passed in, and its whole
    effect was to make the two "add your own" controls refuse: tapping them
    toasted "can be added after profile setup" and did nothing. That was the
    inert control this project does not allow, and it landed on exactly the
    person least able to work around it — a new worker in a trade the seeded
    list of 17 categories does not name, at the one moment they are being
    asked what they do.

    Nothing needed it. /categories and /skills are taxonomy endpoints that
    require only a logged-in account, not a saved worker profile, so they
    already worked mid-setup; the rows they create are global and outlive the
    draft either way. Abuse is bounded where it should be, by the five-custom-
    categories-per-account cap in CategoryController, not by hiding the button
    from new users.
*/
class AddSkillsScreen extends StatefulWidget {
  final List<String> initialSkills;

  const AddSkillsScreen({
    super.key,
    this.initialSkills = const [],
  });

  @override
  State<AddSkillsScreen> createState() => _AddSkillsScreenState();
}

class _AddSkillsScreenState extends State<AddSkillsScreen> {
  final _customSkillCtrl = TextEditingController();
  
  CategoryModel? _selectedCategory;
  final Set<SkillModel> _selectedSkills = {};
  bool _isLoadingCategories = false;
  bool _isLoadingSkills = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _customSkillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final provider = context.read<WorkerProfileProvider>();
    await provider.fetchCategories();
    
    // Load initial skills after categories are loaded
    if (!_isInitialized && widget.initialSkills.isNotEmpty) {
      await _loadInitialSkills(provider);
    }
    
    setState(() => _isLoadingCategories = false);
  }

  Future<void> _loadInitialSkills(WorkerProfileProvider provider) async {
    // One request for the whole catalogue, rather than one per category run
    // back to back — see fetchAllSkills for what that was costing.
    final allSkills = await provider.fetchAllSkills();
    
    // Match initial skill names with actual SkillModel objects
    for (var skillName in widget.initialSkills) {
      final matchingSkill = allSkills.firstWhere(
        (s) => s.name.toLowerCase() == skillName.toLowerCase(),
        orElse: () => SkillModel(
          id: -1, // Temporary ID for custom skills not yet in DB
          name: skillName,
          categoryId: 0,
        ),
      );
      _selectedSkills.add(matchingSkill);
    }
    
    _isInitialized = true;
    setState(() {});
  }

  Future<void> _loadSkillsForCategory(CategoryModel category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingSkills = true;
    });
    final provider = context.read<WorkerProfileProvider>();
    await provider.fetchSkillsByCategory(category.id);
    setState(() => _isLoadingSkills = false);
  }

  /// Compared by identity, which is not what selection means here.
  ///
  /// The same skill arrives as a different SkillModel instance every time the
  /// list is refetched, and the model defines no equality, so contains() and
  /// remove() both answer against object identity. Selecting a skill, changing
  /// category, and coming back left a chip that looked selected and could not
  /// be unselected. Matching on the id — or on the name, for a custom skill
  /// that has no id yet — is what the user means by "the same skill".
  bool _isSelected(SkillModel skill) => _selectedSkills.any((s) => _same(s, skill));

  static bool _same(SkillModel a, SkillModel b) {
    if (a.id > 0 && b.id > 0) return a.id == b.id;
    return a.name.toLowerCase() == b.name.toLowerCase();
  }

  void _toggleSkill(SkillModel skill) {
    setState(() {
      if (_isSelected(skill)) {
        _selectedSkills.removeWhere((s) => _same(s, skill));
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  Future<void> _addCustomSkill() async {
    final val = _customSkillCtrl.text.trim();
    if (val.isEmpty) return;
    
    if (_selectedCategory == null) {
      AppToast.info(context, 'Please select a job category first');
      return;
    }

    // Check if skill already exists in selected skills
    final existsInSelected = _selectedSkills.any((s) => s.name.toLowerCase() == val.toLowerCase());
    if (existsInSelected) {
      AppToast.info(context, 'Skill already selected');
      return;
    }

    setState(() => _isLoadingSkills = true);
    final provider = context.read<WorkerProfileProvider>();
    final newSkill = await provider.createCustomSkill(val, _selectedCategory!.id);

    /*
        Nothing below this line is safe without it.

        Creating a skill is a network round trip, and backing out of the screen
        during one is normal. Every line after this used the screen's context
        and called setState on a State that could already be gone - which
        throws, and the exception surfaces as a red screen rather than as the
        harmless cancellation it is.
    */
    if (!mounted) return;

    if (newSkill != null) {
      setState(() {
        _selectedSkills.add(newSkill);
        _customSkillCtrl.clear();
      });
    } else {
      AppToast.info(context, provider.errorMessage ?? 'Failed to add custom skill');
    }
    setState(() => _isLoadingSkills = false);
  }

  Future<void> _showAddCustomCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Job Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g., Solar Panel Maintenance',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoadingCategories = true);
      final provider = context.read<WorkerProfileProvider>();
      final newCategory = await provider.createCustomCategory(result);

      // Same as above: this awaited, and the screen may have gone.
      if (!mounted) return;

      if (newCategory != null) {
        await _loadSkillsForCategory(newCategory);
      } else {
        AppToast.info(context, provider.errorMessage ?? 'Failed to create category');
      }
      setState(() => _isLoadingCategories = false);
    }
  }

  void _save() {
    // Return the full SkillModel objects with category info
    Navigator.pop(context, _selectedSkills.toList());
  }

  String? _getCategoryName(int categoryId) {
    final provider = context.read<WorkerProfileProvider>();
    try {
      return provider.categories.firstWhere((c) => c.id == categoryId).name;
    } catch (e) {
      return null;
    }
  }

  List<Widget> _buildGroupedSkills() {
    // Group skills by category
    final Map<int, List<SkillModel>> grouped = {};
    for (var skill in _selectedSkills) {
      grouped.putIfAbsent(skill.categoryId, () => []).add(skill);
    }
    
    // Build widgets for each category group
    final List<Widget> widgets = [];
    
    grouped.forEach((categoryId, skills) {
      final categoryName = _getCategoryName(categoryId) ?? 'Other';
      
      // Category header
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8, top: widgets.isEmpty ? 0 : 12),
          child: Text(
            categoryName.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.neutral600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      
      // Skills in this category
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skills.map((skill) => Container(
            key: ValueKey(skill.id),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(skill.name, style: const TextStyle(fontSize: 13.5, color: AppColors.primary)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _toggleSkill(skill),
                  child: const Icon(Icons.close, size: 15, color: AppColors.primary),
                ),
              ],
            ),
          )).toList(),
        ),
      );
    });
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkerProfileProvider>();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Skills',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected skills preview
                  Row(
                    children: [
                      const Text('Selected',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_selectedSkills.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_selectedSkills.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildGroupedSkills(),
                    ),
                  if (_selectedSkills.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                  ],

                  // Category selection
                  Row(
                    children: [
                      const Text('1. Select Job Category',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showAddCustomCategoryDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Custom Job', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  if (_isLoadingCategories)
                    const Center(child: CircularProgressIndicator())
                  else if (provider.categories.isEmpty)
                    const Text('No categories available', style: TextStyle(color: AppColors.neutral400))
                  else
                    DropdownButtonFormField<CategoryModel>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        hintText: 'Choose a job category',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      items: provider.categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              if (category.isCustom) ...[
                                const Icon(Icons.star, size: 16, color: AppColors.accent),
                                const SizedBox(width: 8),
                              ],
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (category) {
                        if (category != null) {
                          _loadSkillsForCategory(category);
                        }
                      },
                    ),

                  const SizedBox(height: 24),

                  // Skills for selected category
                  if (_selectedCategory != null) ...[
                    const Text('2. Select Skills',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                    const SizedBox(height: 8),
                    
                    if (_isLoadingSkills)
                      const Center(child: CircularProgressIndicator())
                    else if (provider.availableSkills.isEmpty)
                      const Text('No predefined skills. Add a custom skill below.',
                          style: TextStyle(color: AppColors.neutral400))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: provider.availableSkills.map((skill) {
                          final selected = _isSelected(skill);
                          return GestureDetector(
                            key: ValueKey(skill.id),
                            onTap: () => _toggleSkill(skill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.neutral300,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    const Icon(Icons.check, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(skill.name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                        color: selected ? AppColors.primary : AppColors.neutral700,
                                      )),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 20),

                    // Custom skill input
                    const Text('3. Or Add Custom Skill',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSkillCtrl,
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _addCustomSkill(),
                            decoration: InputDecoration(
                              hintText: 'Enter custom skill for ${_selectedCategory!.name}',
                              hintStyle: const TextStyle(color: AppColors.neutral400),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addCustomSkill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Save Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedSkills.isNotEmpty ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.neutral300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _selectedSkills.isEmpty 
                      ? 'Select at least one skill' 
                      : 'Save ${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
