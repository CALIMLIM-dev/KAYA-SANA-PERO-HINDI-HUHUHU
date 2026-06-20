import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Public Employer Profile View
/// Shown to WORKERS when they tap "Posted by" on a job listing.
/// Read-only — shows company info, posted jobs, reviews.
class EmployerProfileScreen extends StatelessWidget {
  const EmployerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Receive employer data via route arguments from job details
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
                        // Logo + name row
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
                                      const Text(
                                        'Plumbing Services Inc.',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
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
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 13, color: Colors.white70),
                                      SizedBox(width: 3),
                                      Text(
                                        'Pangasinan, Philippines',
                                        style: TextStyle(
                                            fontSize: 13, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Stats row
                        Row(
                          children: [
                            _headerStat('4.8', 'Rating'),
                            _divider(),
                            _headerStat('89', 'Reviews'),
                            _divider(),
                            _headerStat('24', 'Jobs Posted'),
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
          SliverToBoxAdapter(
            child: _section(
              title: 'About',
              child: const Text(
                'We are a professional plumbing services company operating in Pangasinan for over 10 years. We specialize in residential and commercial plumbing repairs, installations, and emergency services.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.neutral700,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // ── Contact Info ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _section(
              title: 'Contact',
              child: Column(
                children: [
                  _contactRow(Icons.phone_outlined, '+63 912 345 6789'),
                  const SizedBox(height: 10),
                  _contactRow(Icons.email_outlined, 'contact@plumbingservices.com'),
                  const SizedBox(height: 10),
                  _contactRow(Icons.location_on_outlined, 'Pangasinan, Philippines'),
                ],
              ),
            ),
          ),

          // ── Active Jobs ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _section(
              title: 'Active Job Postings',
              child: Column(
                children: [
                  _jobRow(
                    context,
                    title: 'Emergency Pipe Repair',
                    salary: '₱1,200/day',
                    location: 'Pangasinan',
                    postedDate: '2 hours ago',
                  ),
                  const Divider(height: 20),
                  _jobRow(
                    context,
                    title: 'Bathroom Plumbing Install',
                    salary: '₱1,500/day',
                    location: 'Dagupan City',
                    postedDate: '1 day ago',
                  ),
                ],
              ),
            ),
          ),

          // ── Reviews ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _section(
              title: 'Reviews (89)',
              child: Column(
                children: [
                  _reviewRow(
                    name: 'Juan Dela Cruz',
                    rating: 5,
                    date: '3 days ago',
                    comment: 'Very professional and responsive employer. Paid on time and clearly described the work needed.',
                    initial: 'J',
                  ),
                  const Divider(height: 20),
                  _reviewRow(
                    name: 'Maria Santos',
                    rating: 5,
                    date: '1 week ago',
                    comment: 'Great experience. Would definitely work with them again.',
                    initial: 'M',
                  ),
                  const Divider(height: 20),
                  _reviewRow(
                    name: 'Pedro Reyes',
                    rating: 4,
                    date: '2 weeks ago',
                    comment: 'Good employer, fair pay, work was clearly explained.',
                    initial: 'P',
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
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
        Text(value,
            style: const TextStyle(
                fontSize: 14, color: AppColors.neutral700)),
      ],
    );
  }

  Widget _jobRow(
    BuildContext context, {
    required String title,
    required String salary,
    required String location,
    required String postedDate,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/job-details'),
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
                    Text(location,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral500)),
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
    required String initial,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(initial,
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
                fontSize: 13,
                color: AppColors.neutral700,
                height: 1.5)),
      ],
    );
  }
}
