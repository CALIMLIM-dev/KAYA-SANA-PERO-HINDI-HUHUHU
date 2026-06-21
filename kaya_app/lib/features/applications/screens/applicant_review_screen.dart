import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Applicant Review Screen — employer reviews a single applicant
/// Per product rules: shows Profile Picture, Full Name, Verification Status,
/// Skills, Experience, Certifications, Rating, Previous Reviews, Availability.
/// Buttons: Accept Applicant, Reject Applicant, View Full Profile.
class ApplicantReviewScreen extends StatefulWidget {
  const ApplicantReviewScreen({super.key});

  @override
  State<ApplicantReviewScreen> createState() => _ApplicantReviewScreenState();
}

class _ApplicantReviewScreenState extends State<ApplicantReviewScreen> {
  // TODO: Receive real applicant data via route arguments
  // Using mock data for frontend completion
  String _applicationStatus = 'pending'; // pending | accepted | rejected

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Mock applicant data — TODO: replace with real arg
    final applicant = args ?? {
      'name': 'Juan Dela Cruz',
      'isVerified': true,
      'rating': 4.9,
      'reviewCount': 127,
      'location': 'Pangasinan',
      'experience': '5 years',
      'availability': 'Available',
      'skills': ['Plumbing', 'Pipe Repair', 'Leak Detection', 'Installation', 'Emergency Service'],
      'experiences': [
        {'title': 'Senior Plumber', 'company': 'ABC Plumbing Services', 'duration': '2020 – Present'},
        {'title': 'Plumber', 'company': 'XYZ Construction', 'duration': '2018 – 2020'},
      ],
      'certifications': [
        {'title': 'Licensed Plumber', 'issuer': 'PPA', 'year': '2019'},
        {'title': 'Safety Certification', 'issuer': 'DOLE', 'year': '2021'},
      ],
      'reviews': [
        {
          'reviewer': 'Maria Santos',
          'rating': 5,
          'comment': 'Very professional and quick. Fixed the burst pipe same day.',
          'date': '2 days ago',
        },
        {
          'reviewer': 'Pedro Gonzales',
          'rating': 5,
          'comment': 'Great work, fair price. Will hire again.',
          'date': '1 week ago',
        },
        {
          'reviewer': 'Ana Reyes',
          'rating': 4,
          'comment': 'Good service, arrived on time.',
          'date': '2 weeks ago',
        },
      ],
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
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
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              child: Text(
                                (applicant['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (applicant['isVerified'] == true)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Name + verified
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              applicant['name'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (applicant['isVerified'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified,
                                        size: 11, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text('Verified',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Rating + location
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              '${applicant['rating']} (${applicant['reviewCount']} reviews)',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on,
                                size: 13, color: Colors.white60),
                            const SizedBox(width: 3),
                            Text(applicant['location'],
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Status banner (if already decided) ──
                if (_applicationStatus != 'pending')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    color: _applicationStatus == 'accepted'
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _applicationStatus == 'accepted'
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 16,
                          color: _applicationStatus == 'accepted'
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _applicationStatus == 'accepted'
                              ? 'Applicant Accepted — Messaging Unlocked'
                              : 'Applicant Rejected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _applicationStatus == 'accepted'
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // ── Availability ──
                _section(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Availability',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.neutral500)),
                            Text(
                              applicant['availability'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.work_outline,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Experience',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.neutral500)),
                            Text(
                              applicant['experience'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Skills ──
                _section(
                  title: 'Skills',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (applicant['skills'] as List)
                          .map((skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(skill,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primary)),
                              ))
                          .toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Experience ──
                _section(
                  title: 'Work Experience',
                  children: [
                    ...(applicant['experiences'] as List).map((exp) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.work_outline,
                                    size: 18, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(exp['title'],
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.neutral900)),
                                    Text(exp['company'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.neutral600)),
                                    Text(exp['duration'],
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.neutral400)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Certifications ──
                _section(
                  title: 'Certifications',
                  children: [
                    ...(applicant['certifications'] as List).map((cert) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.verified,
                                    size: 18, color: AppColors.success),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cert['title'],
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.neutral900)),
                                    Text(
                                        '${cert['issuer']} • ${cert['year']}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.neutral500)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Verified',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Reviews ──
                _section(
                  title: 'Previous Reviews',
                  children: [
                    ...(applicant['reviews'] as List)
                        .asMap()
                        .entries
                        .map((entry) {
                      final i = entry.key;
                      final review = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i > 0) const Divider(height: 20),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  (review['reviewer'] as String)[0],
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review['reviewer'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.neutral900)),
                                    Row(
                                      children: [
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < (review['rating'] as int)
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 12,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(review['date'],
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.neutral400)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(review['comment'],
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.neutral700,
                                  height: 1.5)),
                        ],
                      );
                    }),
                  ],
                ),

                // Bottom padding for the action bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Action bar ──────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: _applicationStatus == 'pending'
              ? Row(
                  children: [
                    // View Full Profile
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/worker-profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('View Full Profile',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),

                    // Reject
                    ElevatedButton(
                      onPressed: () => _showRejectDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: AppColors.error,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),

                    // Accept
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAcceptDialog(applicant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accept Applicant',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              // Already decided — show message button if accepted
              : _applicationStatus == 'accepted'
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/messages'),
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Send Message',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  Widget _section(
      {String? title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          if (title != null) ...[
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral900)),
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
  }

  void _showAcceptDialog(Map<String, dynamic> applicant) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Applicant?'),
        content: Text(
            'Accept ${applicant['name']}? Messaging will be unlocked between you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _applicationStatus = 'accepted');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('${applicant['name']} accepted — messaging unlocked'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            child: const Text('Accept',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Applicant?'),
        content: const Text('This applicant will be notified of your decision.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _applicationStatus = 'rejected');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Applicant rejected')),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
