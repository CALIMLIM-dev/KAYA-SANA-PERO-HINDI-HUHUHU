import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../core/widgets/verification_badge_widget.dart';
import '../../../data/services/api_client.dart';

/*
    Who viewed your profile, and how your weeks went.

    A top-up benefit: every account sees how many looked this week; a
    topped-up one sees who, and eight weeks of views. Opened from the
    "N viewed your profile" line on your own profile.
*/
Future<void> showProfileViewsPopup(BuildContext context, {String side = 'worker'}) {
  return showKayaPopup<void>(context, builder: (_) => _ProfileViews(side: side));
}

class _ProfileViews extends StatefulWidget {
  const _ProfileViews({required this.side});

  final String side;

  @override
  State<_ProfileViews> createState() => _ProfileViewsState();
}

class _ProfileViewsState extends State<_ProfileViews> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient().get('/profile-views/insights', queryParameters: {'as': widget.side});
      if (!mounted) return;
      setState(() => _data = Map<String, dynamic>.from(res.data['data'] as Map));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Profile Views', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (data == null)
            _error == null
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                : Text(_error!, style: const TextStyle(color: AppColors.neutral600))
          else ..._body(data),
        ],
      ),
    );
  }

  List<Widget> _body(Map<String, dynamic> data) {
    final week = Map<String, dynamic>.from(data['this_week'] as Map? ?? const {});
    final views = (week['views'] as num?)?.toInt() ?? 0;
    final people = (week['people'] as num?)?.toInt() ?? 0;
    final unlocked = data['unlocked'] == true;

    return [
      Text(
        'This week: $views view${views == 1 ? '' : 's'} from $people ${people == 1 ? 'person' : 'people'}',
        style: const TextStyle(fontSize: 14, color: AppColors.neutral800),
      ),
      const SizedBox(height: 16),
      if (!unlocked) ...[
        const Text(
          'Top up any amount once to see who viewed you and your last eight weeks.',
          style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.neutral600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await AppRouter.push(context, AppRouter.wallet);
              if (mounted) _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Top Up'),
          ),
        ),
      ] else ...[
        _weeks((data['weeks'] as List? ?? const []).map((w) => Map<String, dynamic>.from(w as Map)).toList()),
        const SizedBox(height: 18),
        const Text('Who Viewed Your Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral700)),
        const SizedBox(height: 6),
        ..._viewers((data['viewers'] as List? ?? const []).map((v) => Map<String, dynamic>.from(v as Map)).toList()),
      ],
    ];
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Eight bars, oldest first, each week's count above it.
  Widget _weeks(List<Map<String, dynamic>> weeks) {
    final top = weeks.fold<int>(1, (m, w) => ((w['views'] as num?)?.toInt() ?? 0) > m ? (w['views'] as num).toInt() : m);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final w in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${w['views']}', style: const TextStyle(fontSize: 11, color: AppColors.neutral700)),
                    const SizedBox(height: 3),
                    // The bar takes what the two labels leave, so a larger
                    // text size shortens the bars instead of overflowing.
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (((w['views'] as num?)?.toInt() ?? 0) / top).clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_weekLabel(w['week_of']), style: const TextStyle(fontSize: 10, color: AppColors.neutral500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _weekLabel(Object? iso) {
    final d = DateTime.tryParse('$iso');
    return d == null ? '' : '${_months[d.month - 1]} ${d.day}';
  }

  List<Widget> _viewers(List<Map<String, dynamic>> viewers) {
    if (viewers.isEmpty) {
      return const [Text('Nobody in the last eight weeks.', style: TextStyle(fontSize: 13.5, color: AppColors.neutral600))];
    }

    return [
      for (final v in viewers)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.neutral100,
                backgroundImage: (v['avatar'] as String?)?.isNotEmpty == true ? NetworkImage(v['avatar'] as String) : null,
                child: (v['avatar'] as String?)?.isNotEmpty == true
                    ? null
                    : Text('${v['name'] ?? '?'}'.isEmpty ? '?' : '${v['name']}'[0].toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.neutral600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text('${v['name'] ?? 'Someone'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.neutral900)),
                    ),
                    const SizedBox(width: 6),
                    VerificationChip(state: VerificationState.of(v), size: 10),
                  ],
                ),
              ),
              Text(_dayLabel(v['viewed_on']), style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
            ],
          ),
        ),
    ];
  }

  String _dayLabel(Object? iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '';
    final now = DateTime.now();
    final ago = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    return ago == 0 ? 'Today' : ago == 1 ? 'Yesterday' : '${_months[d.month - 1]} ${d.day}';
  }
}
