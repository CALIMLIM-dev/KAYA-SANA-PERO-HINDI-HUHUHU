import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/worker_browse_provider.dart';

/// Public Worker Profile Screen — shown to employers when browsing workers.
/// Reads {'workerId': int} from route arguments and fetches the real profile
/// via GET /workers/{id}.
class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  int? _workerId;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['workerId'];
      _workerId = raw is int ? raw : int.tryParse('$raw');
    } else if (args is int) {
      _workerId = args;
    }

    _requested = true;
    final id = _workerId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<WorkerBrowseProvider>().fetchWorkerDetail(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_workerId == null) {
      return const Scaffold(body: Center(child: Text('No worker specified.')));
    }

    return Consumer<WorkerBrowseProvider>(
      builder: (context, provider, _) {
        if (provider.isDetailLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (provider.detailErrorMessage != null || provider.selectedWorker == null) {
          return _errorState(context, provider.detailErrorMessage ?? 'Worker not found.');
        }
        return _content(context, provider.selectedWorker!);
      },
    );
  }

  Widget _errorState(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.neutral400),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context
                    .read<WorkerBrowseProvider>()
                    .fetchWorkerDetail(_workerId!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // rating_avg is a Laravel `decimal` cast, which serializes as a STRING
  // ("4.50"), not a JSON number — `as num?` throws on it. Parse defensively,
  // same as Job.fromApi already does for budget_min/max.
  double _asDouble(Object? v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  int _asInt(Object? v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  Widget _content(BuildContext context, Map<String, dynamic> w) {
    final name = (w['name'] as String?) ?? 'Worker';
    final category = (w['category'] as String?) ?? '';
    final location = (w['location'] as String?) ?? '';
    final rating = _asDouble(w['rating_avg']);
    final reviewCount = _asInt(w['rating_count']);
    final isVerified = (w['is_verified'] as bool?) ?? false;
    final availability = (w['availability_status'] as String?) ?? 'unavailable';
    final isAvailable = availability == 'available';
    final bio = (w['bio'] as String?) ?? '';
    final skills = ((w['skills'] as List?) ?? [])
        .map((s) => s is Map ? (s['name']?.toString() ?? '') : s.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final experiences = ((w['experiences'] as List?) ?? []).cast<Map<String, dynamic>>();
    final certifications = ((w['certifications'] as List?) ?? []).cast<Map<String, dynamic>>();
    final reviews = ((w['reviews'] as List?) ?? []).cast<Map<String, dynamic>>();
    final yearsOfExperience = experiences.length;

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Profile Header ──
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                            if (isVerified)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: AppColors.verified,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(category,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9))),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(location,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (reviewCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 6),
                                Text(rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Text('($reviewCount reviews)',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14)),
                              ],
                            ),
                          )
                        else
                          const Text('No reviews yet',
                              style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.neutral50,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.work_outline,
                      value: isAvailable ? 'Available' : 'Unavailable',
                      label: 'Status',
                      color: isAvailable ? AppColors.success : AppColors.neutral400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.schedule,
                      value: '$yearsOfExperience job${yearsOfExperience == 1 ? '' : 's'}',
                      label: 'Experience',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      icon: Icons.verified_user,
                      value: isVerified ? 'Verified' : 'Unverified',
                      label: 'Account',
                      color: isVerified ? AppColors.success : AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action Buttons ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showInviteDialog(context, name),
                      icon: const Icon(Icons.person_add_outlined, size: 20),
                      label: const Text('Invite to Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      // No conversation exists until an application/invitation
                      // is accepted (see ConversationController) — send them to
                      // the real inbox rather than a chat with nothing behind it.
                      onPressed: () => Navigator.pushNamed(context, '/messages'),
                      icon: const Icon(Icons.message_outlined, size: 20),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (bio.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'About',
                child: Text(bio,
                    style: const TextStyle(
                        fontSize: 15, height: 1.6, color: AppColors.neutral700)),
              ),
            ),

          if (bio.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (skills.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Skills & Expertise',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((s) => _skillChip(s, Icons.build)).toList(),
                ),
              ),
            ),

          if (skills.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (experiences.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Work Experience',
                child: Column(
                  children: experiences
                      .map((exp) => _experienceItem(
                            title: (exp['title'] ?? '').toString(),
                            company: (exp['company'] ?? '').toString(),
                            duration: _formatDuration(exp),
                            description: (exp['description'] ?? '').toString(),
                          ))
                      .toList(),
                ),
              ),
            ),

          if (experiences.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (certifications.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Certifications',
                child: Column(
                  children: certifications
                      .map((cert) => _certItem(
                            title: (cert['title'] ?? '').toString(),
                            issuer: (cert['issuer'] ?? '').toString(),
                            year: (cert['year'] ?? '').toString(),
                          ))
                      .toList(),
                ),
              ),
            ),

          if (certifications.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (reviews.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Reviews & Ratings',
                showSeeAll: reviews.length > 3,
                child: Column(
                  children: [
                    for (var i = 0; i < reviews.length && i < 3; i++) ...[
                      _reviewItem(
                        name: (reviews[i]['reviewer'] ?? '').toString(),
                        rating: (reviews[i]['rating'] as num?)?.toInt() ?? 5,
                        date: (reviews[i]['date'] ?? '').toString(),
                        comment: (reviews[i]['comment'] ?? '').toString(),
                      ),
                      if (i < 2 && i < reviews.length - 1) const Divider(height: 24),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: _section(
                title: 'Reviews & Ratings',
                child: const Text('No reviews yet.',
                    style: TextStyle(color: AppColors.neutral600, fontSize: 14)),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _formatDuration(Map<String, dynamic> exp) {
    final start = (exp['start_date'] as String?)?.split('-').take(2).join('/') ?? '';
    final isCurrent = exp['is_current'] == true;
    final end = isCurrent
        ? 'Present'
        : ((exp['end_date'] as String?)?.split('-').take(2).join('/') ?? '');
    if (start.isEmpty && end.isEmpty) return '';
    return '$start – $end';
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _section({
    required String title,
    required Widget child,
    bool showSeeAll = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900)),
              if (showSeeAll)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('See All',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral900),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _skillChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _experienceItem({
    required String title,
    required String company,
    required String duration,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work_outline, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900)),
                const SizedBox(height: 2),
                Text(company,
                    style: const TextStyle(fontSize: 14, color: AppColors.neutral700)),
                if (duration.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(duration,
                      style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.neutral600, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _certItem({
    required String title,
    required String issuer,
    required String year,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900)),
                Text('$issuer • $year',
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem({
    required String name,
    required int rating,
    required String date,
    required String comment,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900)),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(date,
                          style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(comment,
            style: const TextStyle(fontSize: 14, color: AppColors.neutral700, height: 1.5)),
      ],
    );
  }

  void _showInviteDialog(BuildContext context, String workerName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite to Apply'),
        content: Text('Select a job post to invite $workerName to apply for:'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invitation sent to $workerName!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Select Job', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
