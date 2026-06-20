import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Comprehensive FAQ Screen
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQSection(
            context,
            'Getting Started',
            [
              _FAQItem(
                question: 'How do I create an account?',
                answer: 'Tap "Get Started" on the welcome screen, fill in your details, and verify your phone number. You\'ll then choose whether you\'re looking for work or need to hire someone.',
              ),
              _FAQItem(
                question: 'How do I switch between looking for work and hiring?',
                answer: 'Use the toggle at the top of the home screen anytime to switch between modes. Your account works for both - no need to create separate profiles.',
              ),
              _FAQItem(
                question: 'What\'s the difference between the two modes?',
                answer: 'In "Looking for work" mode, you browse and apply for jobs. In "Need to hire" mode, you post jobs and review applications from workers.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'For Job Seekers',
            [
              _FAQItem(
                question: 'How do I apply for jobs?',
                answer: 'Browse jobs on the home screen or search page, tap on a job that interests you, and tap "Apply Now". Your application will be sent directly to the employer.',
              ),
              _FAQItem(
                question: 'How do I track my applications?',
                answer: 'Check the Applications tab to see all your job applications organized by status: Pending, Accepted, Rejected, and Completed.',
              ),
              _FAQItem(
                question: 'What happens after I apply?',
                answer: 'The employer will review your application and either accept or reject it. If accepted, messaging will be unlocked so you can discuss job details.',
              ),
              _FAQItem(
                question: 'How do I complete my worker profile?',
                answer: 'Go to Profile > Edit Profile to add your skills, experience, certifications, and availability. A complete profile gets more job offers.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'For Employers',
            [
              _FAQItem(
                question: 'How do I post a job?',
                answer: 'Tap the yellow "+" button on the home screen, fill in the job details (title, description, budget, requirements), and tap "Post Job".',
              ),
              _FAQItem(
                question: 'How do I find workers?',
                answer: 'Post a job and workers will apply, or browse available workers on the home screen and send them job invitations.',
              ),
              _FAQItem(
                question: 'What are job invitations?',
                answer: 'You can invite specific workers to apply for your jobs. This helps you reach qualified candidates who might not have seen your job post yet.',
              ),
              _FAQItem(
                question: 'How do I review applications?',
                answer: 'You\'ll get notifications when workers apply. Review their profiles, skills, and experience, then accept or reject their applications.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Verification & Safety',
            [
              _FAQItem(
                question: 'What does verification mean?',
                answer: 'Verified users have confirmed their identity and skills through our verification process. Look for the blue checkmark badge.',
              ),
              _FAQItem(
                question: 'How do I get verified?',
                answer: 'Go to Profile > Verification and follow the steps to submit your ID and relevant certifications. Verification typically takes 24-48 hours.',
              ),
              _FAQItem(
                question: 'Is KAYA safe to use?',
                answer: 'We verify user identities, have a review system, and secure messaging. Always meet in public places and trust your instincts.',
              ),
              _FAQItem(
                question: 'How do I report a problem?',
                answer: 'Use the "Report" option in conversations or profiles, or contact support through Profile > Help & Support.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Payments & Reviews',
            [
              _FAQItem(
                question: 'How do payments work?',
                answer: 'KAYA facilitates job matching. Payment terms and methods are agreed upon directly between employer and worker.',
              ),
              _FAQItem(
                question: 'How do I leave a review?',
                answer: 'After completing a job, both employer and worker can leave reviews in the Applications tab. Reviews help build trust in the community.',
              ),
              _FAQItem(
                question: 'Can I edit or delete my review?',
                answer: 'Reviews can be edited within 24 hours of posting. Contact support if you need help with review issues.',
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.help_center,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Still need help?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact our support team anytime',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to contact support
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Contact Support'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context, String title, List<_FAQItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildExpandableFAQ(context, item)).toList(),
      ],
    );
  }

  Widget _buildExpandableFAQ(BuildContext context, _FAQItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: ExpansionTile(
        title: Text(
          item.question,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              item.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.neutral700,
                height: 1.5,
              ),
            ),
          ),
        ],
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _FAQItem {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });
}