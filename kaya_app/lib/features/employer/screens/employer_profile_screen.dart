import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/badge_strip.dart';
import '../../../core/widgets/work_record.dart';
import '../../../providers/employer_profile_provider.dart';

/// Public Employer Profile View — shown to workers when they tap "Posted by"
/// on a job listing. Reads {'employerId': int} from route arguments and
/// fetches via GET /employers/{id}.
class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> {
  int? _employerId;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['employerId'];
      _employerId = raw is int ? raw : int.tryParse('$raw');
    } else if (args is int) {
      _employerId = args;
    }

    _requested = true;
    final id = _employerId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<EmployerProfileProvider>().fetchEmployerDetail(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_employerId == null) {
      return const Scaffold(body: Center(child: Text('No employer specified.')));
    }

    return Consumer<EmployerProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isPublicDetailLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (provider.publicDetailErrorMessage != null || provider.publicEmployer == null) {
          return _errorState(context, provider.publicDetailErrorMessage ?? 'Employer not found.');
        }
        return _content(context, provider.publicEmployer!);
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
                    .read<EmployerProfileProvider>()
                    .fetchEmployerDetail(_employerId!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> e) {
    final name = (e['company_name'] as String?) ?? (e['name'] as String?) ?? 'Employer';
    final isVerified = (e['is_verified'] as bool?) ?? false;
    final location = (e['location'] as String?) ?? '';
    final description = (e['description'] as String?) ?? '';
    final website = (e['website'] as String?) ?? '';
    final ratingAvg = (e['rating_avg'] as num?)?.toDouble();
    final reviewCount = (e['rating_count'] as num?)?.toInt() ?? 0;
    final badges = ((e['badges'] as List?) ?? []).cast<Map<String, dynamic>>();
    final jobs = ((e['jobs'] as List?) ?? []).cast<Map<String, dynamic>>();
    final reviews = ((e['reviews'] as List?) ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2),
                              ),
                              child: const Icon(Icons.business,
                                  color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVerified) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified,
                                                  size: 11, color: Colors.white),
                                              SizedBox(width: 3),
                                              Text(
                                                'Verified',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (location.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 13, color: Colors.white70),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            location,
                                            style: const TextStyle(
                                                fontSize: 13.5, color: Colors.white70),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _headerStat(
                                ratingAvg != null ? ratingAvg.toStringAsFixed(1) : '—',
                                'Rating'),
                            _divider(),
                            _headerStat('$reviewCount', 'Reviews'),
                            _divider(),
                            // The server's own count, not the length of the
                            // list beside it — that list stops at 20, so an
                            // employer with more than 20 open jobs was
                            // advertising 20 of them.
                            _headerStat(
                                '${e['open_jobs_count'] ?? jobs.length}',
                                'Open Jobs'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── About ────────────────────────────────────────────────────────────
          if (description.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'About',
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.neutral700,
                    height: 1.6,
                  ),
                ),
              ),
            ),

          // ── Contact Info ─────────────────────────────────────────────────────
          if (location.isNotEmpty || website.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Contact',
                child: Column(
                  children: [
                    if (website.isNotEmpty) ...[
                      _contactRow(Icons.language, website),
                      const SizedBox(height: 10),
                    ],
                    if (location.isNotEmpty)
                      _contactRow(Icons.location_on_outlined, location),
                  ],
                ),
              ),
            ),

          /*
              Badges, before the job list.

              Same widget and same shape as the worker side - the server picks
              which apply, so an employer's set differs in content, not in how
              it is drawn. Nothing renders when none are earned.
          */
          if (badges.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: BadgeStrip(badges: badges),
              ),
            ),

          // ── Active Jobs ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _section(
              title: 'Active Job Postings',
              child: jobs.isEmpty
                  ? const Text('No open job postings right now.',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 14))
                  : Column(
                      children: [
                        for (var i = 0; i < jobs.length; i++) ...[
                          _jobRow(
                            context,
                            jobId: jobs[i]['id'] as int,
                            title: (jobs[i]['title'] ?? '').toString(),
                            salary: _formatSalary(
                                jobs[i]['budget_min'], jobs[i]['budget_max']),
                            location: (jobs[i]['location'] ?? '').toString(),
                            postedDate: (jobs[i]['posted_at'] ?? '').toString(),
                          ),
                          if (i < jobs.length - 1) const Divider(height: 20),
                        ],
                      ],
                    ),
            ),
          ),

          /*
              What their finished work says, above the sections about what
              they claim. Ratings are opinions; this is the record.
          */
          SliverToBoxAdapter(
            child: _section(
              title: 'Completion record',
              child: CompletionRecord(
                completed: (e['jobs_completed'] as num?)?.toInt() ?? 0,
                unsuccessful: (e['jobs_unsuccessful'] as num?)?.toInt() ?? 0,
                successRate: e['success_rate'] as int?,
              ),
            ),
          ),

          /*
              Jobs finished through KAYA, which is the part the app can
              vouch for — as opposed to work experience, which is typed in.
          */
          SliverToBoxAdapter(
            child: _section(
              title: 'Work history on KAYA',
              child: WorkHistoryList(
                history: ((e['history'] as List?) ?? [])
                    .map((h) => Map<String, dynamic>.from(h as Map))
                    .toList(),
              ),
            ),
          ),

          // ── Reviews ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _section(
              title: 'Reviews ($reviewCount)',
              child: reviews.isEmpty
                  ? const Text('No reviews yet.',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 14))
                  : Column(
                      children: [
                        for (var i = 0; i < reviews.length; i++) ...[
                          _reviewRow(
                            name: (reviews[i]['reviewer'] ?? '').toString(),
                            rating: (reviews[i]['rating'] as num?)?.toInt() ?? 5,
                            date: (reviews[i]['date'] ?? '').toString(),
                            comment: (reviews[i]['comment'] ?? '').toString(),
                          ),
                          if (i < reviews.length - 1) const Divider(height: 20),
                        ],
                      ],
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  String _formatSalary(Object? min, Object? max) {
    double? asDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
    final minV = asDouble(min);
    final maxV = asDouble(max);
    if (minV == null && maxV == null) return 'Negotiable';
    if (minV != null && maxV != null && maxV != minV) {
      return '₱${minV.toStringAsFixed(0)}-${maxV.toStringAsFixed(0)}';
    }
    return '₱${(minV ?? maxV)!.toStringAsFixed(0)}';
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _headerStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.neutral700),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _jobRow(
    BuildContext context, {
    required int jobId,
    required String title,
    required String salary,
    required String location,
    required String postedDate,
  }) {
    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, '/job-details', arguments: {'jobId': jobId}),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral900)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.neutral400),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.neutral500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time,
                        size: 12, color: AppColors.neutral400),
                    const SizedBox(width: 3),
                    Text(postedDate,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
                  ],
                ),
              ],
            ),
          ),
          Text(salary,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _reviewRow({
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
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900)),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 13,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(date,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.neutral400)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(comment,
            style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.neutral700,
                height: 1.5)),
      ],
    );
  }
}
