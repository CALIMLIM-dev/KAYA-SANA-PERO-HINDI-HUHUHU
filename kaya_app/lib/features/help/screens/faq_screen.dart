import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Questions people actually ask, answered for the app as it is.
///
/// The earlier version described an app that did not exist: phone
/// verification at sign-up, an Apply Now button, a blue checkmark, reviews
/// editable for 24 hours, a support team reachable from a button whose
/// handler was empty. Every answer here names the screen and the button as
/// they are.
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
            'Accounts',
            [
              const _FAQItem(
                question: 'How do I create an account?',
                answer:
                    'Sign up with your email or phone number and a password, or with Google. '
                    'Then set up a worker profile, an employer profile, or both.',
              ),
              const _FAQItem(
                question: 'Can one account both look for work and hire?',
                answer:
                    'Yes. Set up both profiles and switch with the toggle at the top of the home screen. '
                    'The one exception is a registered business: a business account cannot also be a worker account.',
              ),
              const _FAQItem(
                question: 'What does verified mean?',
                answer:
                    'The person submitted a Philippine government ID and a selfie holding it, and an admin checked them. '
                    'A business also submits its DTI or SEC registration and Mayor\'s permit. '
                    'You can browse without verifying, but posting, applying, inviting and topping up need it.',
              ),
              const _FAQItem(
                question: 'How do I get verified?',
                answer:
                    'Open your profile, then Verification, and upload the documents. '
                    'An admin reviews them and you get a notification either way.',
              ),
              const _FAQItem(
                question: 'How do I delete my account?',
                answer:
                    'Profile, Settings, Delete account. You type your password once more. '
                    'Your profile, documents and photos are removed and cannot be brought back. '
                    'You cannot delete while you are on a job that is not finished.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Looking for work',
            [
              const _FAQItem(
                question: 'How do I apply for a job?',
                answer:
                    'Open the job and tap Apply. Applying costs barya, shown on the button before you confirm. '
                    'You get it back if you withdraw within the grace period, or if the employer removes the job.',
              ),
              const _FAQItem(
                question: 'Where are my applications?',
                answer:
                    'Home, then My Applications. They are grouped by status: pending, accepted, rejected, completed.',
              ),
              const _FAQItem(
                question: 'What happens after I apply?',
                answer:
                    'The employer accepts or rejects. If accepted, a chat opens between the two of you, '
                    'where you can agree a day and time and share your location on the day.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Hiring',
            [
              const _FAQItem(
                question: 'How do I post a job?',
                answer:
                    'In employer mode, tap Post a Job on the home screen. The post runs from its start date '
                    'to its end date. The first week is free; longer costs barya, shown under the dates as you pick them.',
              ),
              const _FAQItem(
                question: 'How do I find workers?',
                answer:
                    'Post a job and workers apply, or open Search in employer mode to browse workers by trade '
                    'and distance and invite one to a job. Inviting costs barya; inviting someone you have hired before costs half.',
              ),
              const _FAQItem(
                question: 'Can I hire more than one person for a job?',
                answer:
                    'Yes. Set how many workers the job needs, one to twenty. The post stays open until every spot is taken. '
                    'The roster lists everyone hired and lets you message them all or mark the job done for all of them.',
              ),
              const _FAQItem(
                question: 'How do I see who applied?',
                answer:
                    'Home, then Active Jobs, then the job. Each applicant shows their profile, skills, rating '
                    'and whether you have hired them before. Accept or reject from there.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Barya and payment',
            [
              const _FAQItem(
                question: 'What is barya?',
                answer:
                    'The app\'s credit. Every account gets some on sign-up and some each month. '
                    'Applying, inviting, boosting and community posts cost barya. A job post is free for its first week, and messaging is free.',
              ),
              const _FAQItem(
                question: 'How do I pay a worker?',
                answer:
                    'Directly. KAYA does not hold or move job payments. Agree the amount and how you will pay in the chat.',
              ),
              const _FAQItem(
                question: 'How do I top up?',
                answer:
                    'Profile, then My Wallet, then choose a package. Payment opens in your browser. You need a verified account.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFAQSection(
            context,
            'Safety',
            [
              const _FAQItem(
                question: 'How do I report someone?',
                answer:
                    'In a chat, open the menu at the top right and choose Report. On a community post, use Report on the post. '
                    'An admin reads the report and can suspend the account.',
              ),
              const _FAQItem(
                question: 'How do reviews work?',
                answer:
                    'After a job is marked complete by both sides, each can review the other: workers from My Applications, employers from My Job Posts. '
                    'A review cannot be edited once sent. An admin can hide a review that breaks the rules.',
              ),
            ],
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
        ...items.map((item) => _buildExpandableFAQ(context, item)),
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
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
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
