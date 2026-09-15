import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/api_client.dart';
import '../screens/skill_check_screen.dart';

/*
    The skill checks a worker can sit, on their own profile.

    Their own trade first. Each row says where they stand: not taken, a
    pass with the date, or a fail with when it opens again. Passing puts
    Skill Checked on the public profile and a chip on the directory card,
    which is the whole reason to sit one.
*/
class SkillCheckCard extends StatefulWidget {
  const SkillCheckCard({super.key, this.onChanged});

  /// Called after a pass, so the screen can refresh the badge ring.
  final VoidCallback? onChanged;

  @override
  State<SkillCheckCard> createState() => _SkillCheckCardState();
}

class _SkillCheckCardState extends State<SkillCheckCard> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _tests = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (await ApiClient.getToken() == null) return;
    try {
      final res = await _api.get('/assessments');
      if (!mounted) return;
      setState(() {
        _tests = ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _take(Map<String, dynamic> test) async {
    final passed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SkillCheckScreen(assessmentId: test['id'] as int)),
    );
    if (!mounted) return;
    await _load();
    if (passed == true) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to offer, nothing drawn: a card that says "no tests" is
    // clutter on every profile until the admin writes one.
    if (!_loaded || _tests.isEmpty) return const SizedBox.shrink();

    // The worker's own trade, plus anything they have passed. The rest of
    // the catalogue is a tap away, not on the profile.
    final shown = _tests.where((t) => t['is_own_trade'] == true || t['passed'] == true).toList();
    final others = _tests.length - shown.length;

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
              Icon(Icons.fact_check_outlined, size: 20, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Skill check',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.neutral900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'A short test on your trade. Pass it and employers see Skill checked on your profile.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.neutral600),
          ),
          const SizedBox(height: 10),
          for (final t in shown) _row(t),
          if (shown.isEmpty)
            for (final t in _tests.take(3)) _row(t),
          if (others > 0 && shown.isNotEmpty)
            TextButton(
              onPressed: () => _showAll(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: Text('$others other trade${others == 1 ? '' : 's'}'),
            ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final passed = t['passed'] == true;
    final canTake = t['can_take'] == true;
    final retry = DateTime.tryParse('${t['retry_at'] ?? ''}');
    final lastScore = (t['last_score'] as num?)?.toInt();

    final String standing;
    if (passed) {
      standing = 'Passed';
    } else if (retry != null) {
      standing = 'Scored $lastScore%. Try again from ${_short(retry)}';
    } else if (lastScore != null) {
      standing = 'Scored $lastScore% last time';
    } else {
      standing = '${t['question_count']} questions, ${t['pass_mark']}% to pass';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            passed ? Icons.verified : Icons.circle_outlined,
            size: 18,
            color: passed ? AppColors.success : AppColors.neutral400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (t['category'] ?? '').toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.neutral900),
                ),
                Text(
                  standing,
                  style: TextStyle(
                    fontSize: 12,
                    color: passed ? AppColors.success : AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
          if (canTake)
            TextButton(
              onPressed: () => _take(t),
              child: Text(lastScore == null ? 'Take test' : 'Try again'),
            ),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            const Text('All skill checks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
            const SizedBox(height: 8),
            for (final t in _tests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text((t['category'] ?? '').toString()),
                subtitle: Text(t['passed'] == true
                    ? 'Passed'
                    : '${t['question_count']} questions, ${t['pass_mark']}% to pass'),
                trailing: t['can_take'] == true
                    ? TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _take(t);
                        },
                        child: const Text('Take test'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  static String _short(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}
