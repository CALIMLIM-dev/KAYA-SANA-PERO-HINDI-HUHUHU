import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/json_parse.dart';
import '../../../providers/worker_browse_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../invitations/widgets/invite_to_job.dart';

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

  /*
      Whether the reviews section is showing all of them.

      See All was a TextButton with an empty handler. On a worker with four or
      more reviews it appeared, invited the tap, and did nothing — and the
      three reviews on screen were the newest, so the ones it was hiding were
      exactly the history someone was trying to read before hiring.

      Expanded in place rather than on a new screen. There is nothing on a
      reviews page that is not already here, and a route would need a new
      screen, a registration and an argument for a list the profile already
      holds.
  */
  bool _showAllReviews = false;

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

  Widget _content(BuildContext context, Map<String, dynamic> w) {
    final name = (w['name'] as String?) ?? 'Worker';
    final category = (w['category'] as String?) ?? '';
    final location = (w['location'] as String?) ?? '';
    final avatar = (w['avatar'] as String?) ?? '';
    final rating = asDouble(w['rating_avg']);
    final reviewCount = asInt(w['rating_count']);
    final isVerified = (w['is_verified'] as bool?) ?? false;
    final availability = (w['availability_status'] as String?) ?? 'unavailable';
    final isAvailable = availability == 'available';
    final bio = (w['bio'] as String?) ?? '';

    // Skills now carry proficiency + years, not just a label — the browse
    // endpoint still sends plain strings, so accept both shapes.
    final skills = ((w['skills'] as List?) ?? [])
        .map((s) => s is Map
            ? Map<String, dynamic>.from(s)
            : <String, dynamic>{'name': s.toString()})
        .where((s) => (s['name']?.toString() ?? '').isNotEmpty)
        .toList();

    final experiences = ((w['experiences'] as List?) ?? []).cast<Map<String, dynamic>>();
    final certifications = ((w['certifications'] as List?) ?? []).cast<Map<String, dynamic>>();
    final licenses = ((w['licenses'] as List?) ?? []).cast<Map<String, dynamic>>();
    final exams = ((w['license_examinations'] as List?) ?? []).cast<Map<String, dynamic>>();
    final reviews = ((w['reviews'] as List?) ?? []).cast<Map<String, dynamic>>();

    final credentialCount = certifications.length + licenses.length + exams.length;

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
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isNotEmpty
                                    ? null
                                    : Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
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
                              style: TextStyle(color: Colors.white60, fontSize: 13.5)),
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
                      icon: Icons.workspace_premium_outlined,
                      value: '$credentialCount',
                      label: 'Credentials',
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
              /*
                  The Message button was removed.

                  It could not do what it said: a conversation only exists once
                  an application or invitation is accepted, so on a worker you
                  have not hired there is nothing to open, and it just dropped
                  you in the inbox. Inviting them to a job is the real way to
                  reach a worker, and once they are accepted the conversation
                  appears in Messages on its own - so that is the only action
                  left here.
              */
              child: SizedBox(
                width: double.infinity,
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

          // ── Trade + skills ──
          // The trade (category) is what the worker actually does; listing
          // bare skill chips without it left an employer guessing.
          SliverToBoxAdapter(
            child: _section(
              // "Trade" is industry jargon a Filipino jobseeker browsing on a
              // phone has no reason to know, and it didn't match the wording
              // used everywhere else in the app.
              title: 'Job Category & Skills',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.handyman_outlined,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Primary Trade',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.neutral500)),
                              const SizedBox(height: 2),
                              Text(category,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.neutral900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (skills.isNotEmpty) const Divider(height: 26),
                  ],
                  if (skills.isNotEmpty)
                    Column(
                      children:
                          skills.map((s) => _skillRow(s)).toList(),
                    )
                  else
                    const Text('No skills listed yet.',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.neutral600)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

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
                      .map((c) => _credentialItem(
                            icon: Icons.verified_outlined,
                            color: AppColors.success,
                            title: (c['title'] ?? '').toString(),
                            subtitle: (c['issuer'] ?? '').toString(),
                            detail: _credentialDates(
                              year: c['year'],
                              expiry: c['expiry_date'],
                              extra: c['credential_id'],
                              extraLabel: 'ID',
                            ),
                            documentUrl: c['document_url'] as String?,
                          ))
                      .toList(),
                ),
              ),
            ),

          if (certifications.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Licenses ──
          // Neither licenses nor license examinations reached this screen
          // before — the two credential types that matter most for trades.
          if (licenses.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Licenses',
                child: Column(
                  children: licenses
                      .map((l) => _credentialItem(
                            icon: Icons.badge_outlined,
                            color: AppColors.primary,
                            title: (l['name'] ?? '').toString(),
                            subtitle: (l['authority'] ?? '').toString(),
                            detail: _credentialDates(
                              year: l['issue_date'],
                              expiry: l['expiry_date'],
                              extra: l['number'],
                              extraLabel: 'No.',
                            ),
                            documentUrl: l['document_url'] as String?,
                          ))
                      .toList(),
                ),
              ),
            ),

          if (licenses.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── License examinations ──
          if (exams.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'License Examinations',
                child: Column(
                  children: exams.map((e) {
                    final status = (e['status'] ?? '').toString();
                    final score = asDoubleOrNull(e['actual_score']);
                    return _credentialItem(
                      icon: status == 'passed'
                          ? Icons.assignment_turned_in_outlined
                          : Icons.assignment_outlined,
                      color: status == 'passed'
                          ? AppColors.success
                          : status == 'failed'
                              ? AppColors.error
                              : AppColors.warning,
                      title: (e['name'] ?? '').toString(),
                      subtitle: [
                        if (status.isNotEmpty)
                          status[0].toUpperCase() + status.substring(1),
                        if (score != null)
                          'Score: ${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 2)}',
                      ].join(' · '),
                      detail: _credentialDates(
                        year: e['exam_date'],
                        extra: e['certificate_number'],
                        extraLabel: 'Cert.',
                      ),
                      documentUrl: e['document_url'] as String?,
                    );
                  }).toList(),
                ),
              ),
            ),

          if (exams.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (reviews.isNotEmpty)
            SliverToBoxAdapter(
              child: _section(
                title: 'Reviews & Ratings',
                showSeeAll: reviews.length > 3,
                seeAllLabel: _showAllReviews ? 'Show less' : 'See all',
                onSeeAll: () =>
                    setState(() => _showAllReviews = !_showAllReviews),
                child: Column(
                  children: [
                    for (var i = 0;
                        i < reviews.length &&
                            (_showAllReviews || i < 3);
                        i++) ...[
                      _reviewItem(
                        name: (reviews[i]['reviewer'] ?? '').toString(),
                        rating: (reviews[i]['rating'] as num?)?.toInt() ?? 5,
                        date: (reviews[i]['date'] ?? '').toString(),
                        comment: (reviews[i]['comment'] ?? '').toString(),
                        tags: ((reviews[i]['tags'] as List?) ?? const [])
                            .map((t) => t.toString())
                            .where((t) => t.isNotEmpty)
                            .toList(),
                      ),
                      if (i < reviews.length - 1 &&
                          (_showAllReviews || i < 2))
                        const Divider(height: 24),
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
    String seeAllLabel = 'See all',
    VoidCallback? onSeeAll,
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
              // Rendered only when it can act. A label that looks like a
              // button and ignores taps is worse than no label.
              if (showSeeAll && onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(seeAllLabel,
                      style: const TextStyle(
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
                  fontSize: 13.5,
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

  /// A skill with its proficiency and years — an employer picking between two
  /// masons needs that detail, not just the label.
  Widget _skillRow(Map<String, dynamic> skill) {
    final name = (skill['name'] ?? '').toString();
    final proficiency = (skill['proficiency_level'] ?? '').toString();
    final years = asIntOrNull(skill['years_of_experience']);

    final profColor = switch (proficiency.toLowerCase()) {
      'expert' => AppColors.success,
      'advanced' => AppColors.primary,
      'intermediate' => AppColors.warning,
      _ => AppColors.neutral500,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.build_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral900)),
          ),
          if (years != null && years > 0) ...[
            Text('$years yr${years == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral500)),
            const SizedBox(width: 8),
          ],
          if (proficiency.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: profColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                proficiency[0].toUpperCase() + proficiency.substring(1),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: profColor),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the small grey line under a credential: issued/expiry dates plus
  /// an identifying number, skipping whatever the worker didn't fill in.
  String _credentialDates({
    Object? year,
    Object? expiry,
    Object? extra,
    String? extraLabel,
  }) {
    String? y(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      if (s.isEmpty) return null;
      // Accept both a bare year ("2026") and a full ISO timestamp.
      final parsed = DateTime.tryParse(s);
      return parsed != null ? '${parsed.year}' : s;
    }

    final parts = <String>[];
    final issued = y(year);
    final exp = y(expiry);

    if (issued != null && exp != null) {
      parts.add('$issued – $exp');
    } else if (issued != null) {
      parts.add('Issued $issued');
    } else if (exp != null) {
      parts.add('Expires $exp');
    }

    final extraStr = extra?.toString().trim() ?? '';
    if (extraStr.isNotEmpty && extraStr.toUpperCase() != 'N/A') {
      parts.add('${extraLabel ?? ''} $extraStr'.trim());
    }

    return parts.join(' · ');
  }

  /// A credential (certification / license / exam) with its supporting
  /// document. The document is the whole point — a claimed license with no
  /// viewable scan is just a text field an employer has to take on faith.
  Widget _credentialItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? detail,
    String? documentUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
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
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.neutral600)),
                if (detail != null && detail.isNotEmpty)
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral500)),
                if (documentUrl != null && documentUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openDocument(documentUrl),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            documentUrl.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          const Text('View document',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text('No document provided',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.neutral400)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Images open in-app (fast, no context switch); PDFs go to the system
  /// viewer because Flutter can't render them without a heavy dependency.
  Future<void> _openDocument(String url) async {
    final isPdf = url.toLowerCase().endsWith('.pdf');

    if (!isPdf) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Could not load document',
                          style: TextStyle(color: Colors.white)),
                    ),
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      AppToast.error(context, 'Could not open the document');
    }
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
                      style: const TextStyle(fontSize: 13.5, color: AppColors.neutral600)),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.neutral600, height: 1.4)),
                ],
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
    List<String> tags = const [],
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

        /*
            What stood out, from the chips the reviewer picked.

            These were collected on the review screen and thrown away — no
            column, no field on the request, nothing rendered. Showing them
            here is the whole reason for asking: a rating says how well the job
            went and this says which part of it.
        */
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Picks one of your open jobs and sends a real invitation.
  ///
  /// The dialog itself now lives in features/invitations, because the chat
  /// offers the same action — reaching a worker you have already hired through
  /// their profile screen was the long way round. Kept as a method here so the
  /// button above reads the same as it always did.
  Future<void> _showInviteDialog(BuildContext context, String workerName) async {
    if (_workerId == null) return;

    await showInviteToJobSheet(context,
        workerId: _workerId!, workerName: workerName);
  }
}
