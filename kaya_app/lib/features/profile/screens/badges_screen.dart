import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/badge_medallion.dart';
import '../../../data/services/api_client.dart';

/*
    Every badge, and what each one takes.

    They were only ever drawn on the public profile - the page somebody else
    opens - so the person earning them saw nothing, had no list of what existed
    and no way to find out what any of them needed. The server answers all of
    that on /me/badges, including how far off the unearned ones are, so this
    screen states the rule and the standing side by side rather than inventing
    either.
*/
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _api = ApiClient();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _worker = const [];
  List<Map<String, dynamic>> _employer = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/me/badges');
      final data = res.data['data'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _worker = ((data['worker'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        _employer = ((data['employer'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: const Text(
          'Badges',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.neutral600),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final earned = [..._worker, ..._employer].where((b) => b['earned'] == true).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            earned == 0
                ? 'Nothing earned yet. Each one below says what it takes.'
                : '$earned earned so far.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(height: 16),
          if (_worker.isNotEmpty) ...[
            _heading('As a worker'),
            ..._worker.map(_tile),
          ],
          if (_employer.isNotEmpty) ...[
            if (_worker.isNotEmpty) const SizedBox(height: 24),
            _heading('As an employer'),
            ..._employer.map(_tile),
          ],
          if (_worker.isEmpty && _employer.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                'Set up a profile and the badges you can earn are listed here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.neutral600, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.neutral500,
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> badge) {
    final isEarned = badge['earned'] == true;
    final label = (badge['label'] ?? '').toString();
    final requirement = (badge['requirement'] ?? '').toString();
    final progress = (badge['progress'] ?? '').toString();

    // The evidence line the award itself carries, when it has one. It says
    // more than repeating the requirement back at somebody who has met it.
    final description = (badge['description'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEarned ? AppColors.primary : AppColors.neutral200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Struck in its own metal when earned, flat grey when not - the
          // shape is the same either way, so the list reads as one set with
          // some of it still to win.
          BadgeMedallion(
            code: (badge['code'] ?? '').toString(),
            earned: isEarned,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isEarned ? AppColors.neutral900 : AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEarned && description != null && description.isNotEmpty
                      ? description
                      : requirement,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.neutral600,
                  ),
                ),
                if (!isEarned && progress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    progress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isEarned)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: Icon(Icons.check, size: 18, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
