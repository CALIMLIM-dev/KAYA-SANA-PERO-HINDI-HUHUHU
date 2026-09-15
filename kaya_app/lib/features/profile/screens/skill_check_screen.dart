import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/services/api_client.dart';

/*
    One skill check, sat here: the questions one after another, four
    choices each, then the result.

    The answers are marked on the server. This screen never knows which
    choice is right, so nothing on the phone can be read to pass it.
*/
class SkillCheckScreen extends StatefulWidget {
  const SkillCheckScreen({super.key, required this.assessmentId});

  final int assessmentId;

  @override
  State<SkillCheckScreen> createState() => _SkillCheckScreenState();
}

class _SkillCheckScreenState extends State<SkillCheckScreen> {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _test;
  List<Map<String, dynamic>> _questions = const [];
  final Map<int, int> _answers = {};
  int _index = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/assessments/${widget.assessmentId}');
      final data = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _test = data;
        _questions = ((data['questions'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final unanswered = _questions.where((q) => !_answers.containsKey(q['id'] as int)).length;
    if (unanswered > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hand it in?'),
          content: Text('$unanswered question${unanswered == 1 ? ' is' : 's are'} unanswered and will count as wrong.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Go back')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hand in')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      final res = await _api.post(
        '/assessments/${widget.assessmentId}/submit',
        data: {'answers': _answers.map((k, v) => MapEntry('$k', v))},
      );
      if (!mounted) return;
      setState(() {
        _result = (res.data['data'] as Map).cast<String, dynamic>();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: Text(
          (_test?['title'] ?? 'Skill check').toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _message(_error!)
              : _result != null
                  ? _resultView(_result!)
                  : _question(),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral600, height: 1.4)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
            ],
          ),
        ),
      );

  Widget _question() {
    final q = _questions[_index];
    final id = q['id'] as int;
    final choices = ((q['choices'] as List?) ?? []).map((c) => c.toString()).toList();
    final chosen = _answers[id];
    final last = _index == _questions.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_index + 1) / _questions.length,
          minHeight: 4,
          backgroundColor: AppColors.neutral200,
          color: AppColors.primary,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Text(
                'Question ${_index + 1} of ${_questions.length}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                (q['prompt'] ?? '').toString(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.neutral900, height: 1.35),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _answers[id] = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: chosen == i ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: chosen == i ? AppColors.primary : AppColors.neutral300,
                          width: chosen == i ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            chosen == i ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20,
                            color: chosen == i ? AppColors.primary : AppColors.neutral400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              choices[i],
                              style: const TextStyle(fontSize: 14.5, height: 1.35, color: AppColors.neutral900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: () => setState(() => _index--),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : last
                          ? _submit
                          : () => setState(() => _index++),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(last ? 'Hand in' : 'Next'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultView(Map<String, dynamic> r) {
    final passed = r['passed'] == true;
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final correct = (r['correct'] as num?)?.toInt() ?? 0;
    final total = (r['total'] as num?)?.toInt() ?? 0;
    final passMark = (r['pass_mark'] as num?)?.toInt() ?? 70;
    final retry = DateTime.tryParse('${r['retry_at'] ?? ''}');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              passed ? Icons.verified : Icons.replay,
              size: 56,
              color: passed ? AppColors.success : AppColors.neutral400,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'You passed' : 'Not this time',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
            const SizedBox(height: 8),
            Text(
              '$correct of $total right, $score%. $passMark% passes.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: AppColors.neutral600, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              passed
                  ? 'Skill checked now shows on your profile and in the worker list.'
                  : retry == null
                      ? 'You can try again later.'
                      : 'You can try again from ${_short(retry)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, passed),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
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
