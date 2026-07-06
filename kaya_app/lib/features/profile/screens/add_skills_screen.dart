import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AddSkillsScreen extends StatefulWidget {
  final List<String> initialSkills;
  const AddSkillsScreen({super.key, this.initialSkills = const []});

  @override
  State<AddSkillsScreen> createState() => _AddSkillsScreenState();
}

class _AddSkillsScreenState extends State<AddSkillsScreen> {
  final _customCtrl = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'Construction & Trades',
      'icon': Icons.construction,
      'color': AppColors.primary,
      'skills': ['Plumbing', 'Electrical', 'Carpentry', 'Masonry', 'Welding', 'Tiling', 'Roofing', 'Painting'],
    },
    {
      'label': 'Home & Facilities',
      'icon': Icons.home_repair_service,
      'color': AppColors.success,
      'skills': ['Air Conditioning', 'Appliance Repair', 'Cleaning', 'Landscaping', 'Pest Control', 'Security'],
    },
    {
      'label': 'Personal & Care',
      'icon': Icons.favorite,
      'color': Colors.pink,
      'skills': ['Caregiver', 'Babysitter', 'Cooking', 'Driving', 'Personal Assistant', 'Laundry'],
    },
    {
      'label': 'Technical',
      'icon': Icons.computer,
      'color': Colors.blue,
      'skills': ['Computer Repair', 'CCTV Installation', 'Solar Panel', 'Data Entry', 'Printing'],
    },
  ];

  late Set<String> _selectedSkills;

  @override
  void initState() {
    super.initState();
    _selectedSkills = Set<String>.from(widget.initialSkills);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggle(String skill) {
    if (_selectedSkills.contains(skill)) {
      _selectedSkills.remove(skill);
    } else {
      _selectedSkills.add(skill);
    }
    setState(() {});
  }

  void _addCustom() {
    final val = _customCtrl.text.trim();
    if (val.isEmpty) return;
    _selectedSkills.add(val);
    _customCtrl.clear();
    setState(() {});
  }

  void _save() {
    Navigator.pop(context, _selectedSkills.toList());
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedSkills.map((skill) => Container(
                        key: ValueKey(skill),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(skill, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _toggle(skill),
                              child: const Icon(Icons.close, size: 15, color: AppColors.primary),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  if (_selectedSkills.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                  ],

                  // Custom skill input
                  const Text('Add Custom Skill',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customCtrl,
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _addCustom(),
                          decoration: InputDecoration(
                            hintText: 'Enter custom skill',
                            hintStyle: TextStyle(color: AppColors.neutral400),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustom,
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

                  const SizedBox(height: 24),

                  // Skill categories
                  ..._categories.map((cat) {
                    final skills = cat['skills'] as List<String>;
                    final color = cat['color'] as Color;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(cat['icon'] as IconData, size: 16, color: color),
                            const SizedBox(width: 6),
                            Text(cat['label'] as String,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((skill) {
                            final selected = _selectedSkills.contains(skill);
                            return GestureDetector(
                              onTap: () => _toggle(skill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected ? color : AppColors.neutral300,
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected) ...[
                                      Icon(Icons.check, size: 13, color: color),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(skill,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                          color: selected ? color : AppColors.neutral700,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),
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
                    _selectedSkills.isEmpty ? 'Select at least one skill' : 'Save ${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'}',
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
