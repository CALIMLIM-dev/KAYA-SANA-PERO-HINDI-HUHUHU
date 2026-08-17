import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Terms and Conditions Modal - Bottom Sheet
/// Shows scrollable terms with tab for Terms and Privacy Policy
/// Checkbox only enables after user scrolls both tabs to bottom
class TermsModal extends StatefulWidget {
  const TermsModal({super.key});

  @override
  State<TermsModal> createState() => _TermsModalState();
}

class _TermsModalState extends State<TermsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _termsScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();
  
  bool _hasScrolledTermsToBottom = false;
  bool _hasScrolledPrivacyToBottom = false;
  bool _checkboxChecked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Listen for scroll events
    _termsScrollController.addListener(_checkTermsScroll);
    _privacyScrollController.addListener(_checkPrivacyScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _termsScrollController.dispose();
    _privacyScrollController.dispose();
    super.dispose();
  }

  void _checkTermsScroll() {
    if (_termsScrollController.position.pixels >=
        _termsScrollController.position.maxScrollExtent - 10) {
      if (!_hasScrolledTermsToBottom) {
        setState(() => _hasScrolledTermsToBottom = true);
      }
    }
  }

  void _checkPrivacyScroll() {
    if (_privacyScrollController.position.pixels >=
        _privacyScrollController.position.maxScrollExtent - 10) {
      if (!_hasScrolledPrivacyToBottom) {
        setState(() => _hasScrolledPrivacyToBottom = true);
      }
    }
  }

  bool get _canEnableCheckbox => _hasScrolledTermsToBottom && _hasScrolledPrivacyToBottom;
  bool get _canAccept => _checkboxChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Terms and Privacy Policy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.neutral900,
              ),
            ),
          ),
          
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.neutral600,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Terms & Conditions'),
              Tab(text: 'Privacy Policy'),
            ],
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScrollIndicatorWrapper(
                  _buildTermsContent(),
                  _termsScrollController,
                  _hasScrolledTermsToBottom,
                ),
                _buildScrollIndicatorWrapper(
                  _buildPrivacyContent(),
                  _privacyScrollController,
                  _hasScrolledPrivacyToBottom,
                ),
              ],
            ),
          ),
          
          // Bottom section with checkbox and buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neutral200)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning if not scrolled both
                  if (!_canEnableCheckbox)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please scroll to the bottom of both tabs',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _checkboxChecked,
                          onChanged: _canEnableCheckbox
                              ? (value) => setState(() => _checkboxChecked = value ?? false)
                              : null,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I have read and agree to the Terms and Conditions and Privacy Policy',
                          style: TextStyle(
                            fontSize: 14,
                            color: _canEnableCheckbox ? AppColors.neutral900 : AppColors.neutral400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.neutral600,
                            side: BorderSide(color: AppColors.neutral300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _canAccept
                              ? () => Navigator.pop(context, true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.neutral300,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollIndicatorWrapper(Widget child, ScrollController controller, bool hasScrolledToBottom) {
    return Stack(
      children: [
        child,
        // Scroll indicator at bottom
        if (!hasScrolledToBottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Scroll to continue',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTermsContent() {
    return SingleChildScrollView(
      controller: _termsScrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            '1. Who Can Use KAYA',
            'KAYA is open to anyone who is at least 18 years old and a resident of the Philippines. You need to be the person you say you are. Creating an account on behalf of someone else, or using false information to sign up, is not allowed and will result in your account being removed.\n\nOne person, one account. If we find duplicate accounts belonging to the same person, we reserve the right to merge or deactivate them.',
          ),
          _buildSection(
            '2. What KAYA Is',
            'KAYA is a marketplace platform. We connect skilled workers in the trades with individuals and businesses that need their services. We are the bridge, not the employer or the client. What happens between workers and employers after they connect through KAYA is a matter between those two parties.\n\nWe do not guarantee employment. We do not guarantee the quality of work performed. We do not handle payments between workers and employers. We exist to make the connection possible.',
          ),
          _buildSection(
            '3. Creating Your Profile',
            'When you set up your profile, you are expected to be honest. The information you provide, whether it is your skills, your work history, your certifications, or your contact details, should be accurate and up to date. Misleading other users through your profile is a violation of these terms.\n\nWorkers who claim certifications or licenses they do not actually hold are putting people at risk. If we receive reports or find evidence that a worker has submitted fake credentials, the account will be permanently banned and the matter may be reported to the appropriate authorities.',
          ),
          _buildSection(
            '4. Verified Badge',
            'The verified badge on KAYA means that our admin team has reviewed and confirmed your identity using the documents you submitted. It does not mean we have tested your skills, observed your work, or vouched for the quality of your services.\n\nGetting verified requires completing three steps: confirming your email address through a one-time code, verifying your phone number through a text message code, and submitting a government-issued ID along with a selfie holding that ID for admin review.\n\nWe reserve the right to revoke the verified status of any account at any time if we have reason to believe the submitted documents were fraudulent or if the account has been flagged for misconduct.',
          ),
          _buildSection(
            '5. Employer Responsibilities',
            'If you are posting jobs on KAYA, the jobs must be real, legal, and fairly described. You cannot post job listings that are misleading, that offer unreasonably low compensation without disclosure, or that are intended to exploit workers.\n\nYou are responsible for the hiring decisions you make. KAYA is not liable for any dispute, conflict, or incident that arises from a working arrangement made through the platform.',
          ),
          _buildSection(
            '6. Worker Responsibilities',
            'If you are offering your services on KAYA, you are responsible for showing up, doing the work you agreed to, and behaving professionally. Any disputes about work quality, incomplete jobs, or payment disagreements are between you and the employer.\n\nYou are also responsible for holding any licenses or certifications required by law for the type of work you offer. KAYA does not verify the legal validity of professional licenses beyond reviewing the documents you submit.',
          ),
          _buildSection(
            '7. What Is Not Allowed',
            'There are certain things that will get your account removed without warning. These include creating a fake identity, submitting fraudulent credentials or government IDs, harassing or threatening other users through the messaging system, posting job listings for illegal activities, using the platform to scam workers or employers, leaving fake reviews to manipulate ratings, and attempting to move transactions off the platform to avoid any accountability.\n\nWe actively monitor for these behaviors. If you come across someone doing any of the above, please use the report feature.',
          ),
          _buildSection(
            '8. Reviews and Ratings',
            'After a job interaction, both workers and employers can leave reviews. These reviews should be honest and based on actual experience. Fake reviews, whether positive or negative, are not allowed. If you receive a review you believe is false or malicious, you can report it to our team for review.\n\nWe do not remove reviews simply because someone disagrees with them. We only intervene if there is clear evidence of abuse.',
          ),
          _buildSection(
            '9. Account Suspension and Termination',
            'We reserve the right to suspend or permanently ban any account that violates these terms. In most cases we will notify you of the reason, but in serious situations such as fraud or harassment, we may act immediately without prior warning.\n\nYou can also delete your own account at any time through the app settings. Deleting your account will remove your profile and personal data in accordance with our privacy policy.',
          ),
          _buildSection(
            '10. Limitation of Liability',
            'KAYA is a student-developed academic capstone project currently in its testing phase. While we have made every effort to build a reliable and secure platform, we cannot guarantee uninterrupted service or be held liable for any losses, damages, or disputes arising from the use of the app.\n\nBy using KAYA, you acknowledge that you understand this and agree not to hold the development team or affiliated institution liable for any outcome of your use of the platform.',
          ),
          _buildSection(
            '11. Changes to These Terms',
            'We may update these terms from time to time. If we make significant changes, we will notify you through the app. Continuing to use KAYA after those changes take effect means you accept the updated terms.',
          ),
          const SizedBox(height: 60), // Extra space for scroll indicator
        ],
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return SingleChildScrollView(
      controller: _privacyScrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            '1. Information We Collect',
            'When you create an account, we collect your full name, email address, and password. When you set up your profile, you may also provide your phone number, location, a profile photo, a short bio, and your availability status.\n\nWorkers who choose to build a more detailed profile may also add skills, work experience, and professional certifications or licenses.\n\nWhen you apply for the verified badge, you will be asked to submit a government-issued ID and a selfie holding that ID. These documents are used solely for identity verification and are reviewed only by authorized KAYA administrators.\n\nWe also collect activity data such as job posts you create or apply to, messages you send through the platform, and reviews you give or receive. This helps us keep the platform running properly and allows us to detect misuse.',
          ),
          _buildSection(
            '2. Why We Collect It',
            'We collect your basic account information to create and manage your account. We collect profile information so other users can find you and understand your background. We collect verification documents to confirm your identity and help build trust between workers and employers on the platform. We collect activity data to operate the app, improve it over time, and investigate any reports of misconduct.\n\nWe do not collect any information we do not need. If you choose not to complete your profile or skip optional fields, you can still use the core features of the app.',
          ),
          _buildSection(
            '3. How We Store and Protect Your Data',
            'Your data is stored on secured servers. Passwords are encrypted and are never stored in plain text. Verification documents such as your ID and selfie are stored separately with restricted access and are only viewable by admin accounts during the verification review process.\n\nWe use industry-standard security practices to protect your information, but no system is completely immune to risk. If you suspect your account has been compromised, please contact us immediately.',
          ),
          _buildSection(
            '4. Who We Share Your Data With',
            'We do not sell your personal information to anyone. We do not share it with advertisers.\n\nWhen you apply for a job or post one, other users will be able to see the information on your public profile. This includes your name, profile photo, bio, skills, and rating. Your government ID, exact phone number, and email are not shown to other users unless you explicitly include them in your public profile.\n\nWe use third-party services to operate the platform, specifically for sending email verification codes and SMS one-time passwords. These services receive only the information necessary to perform their function and are bound by their own privacy policies.\n\nIn cases involving fraud, illegal activity, or a valid legal order, we may be required to share information with law enforcement or regulatory authorities.',
          ),
          _buildSection(
            '5. Verification Documents',
            'We want to be especially clear about how we handle your government-issued ID and selfie because we understand these are sensitive.\n\nYour ID and selfie are submitted for the sole purpose of verifying your identity. They are reviewed manually by our admin team. Once a decision is made, whether your verification is approved or rejected, we retain the documents only for as long as necessary for record-keeping and dispute resolution purposes. You may request the deletion of these documents at any time by contacting us, and we will act on that request within a reasonable timeframe.',
          ),
          _buildSection(
            '6. Certifications and Licenses',
            'If you upload certificates or licenses to your profile, these become part of your public or semi-public worker profile depending on your settings. We store these files on our servers. We do not independently verify the authenticity of professional certificates beyond confirming that a file was uploaded. It is your responsibility to ensure that the documents you upload are genuine and belong to you.',
          ),
          _buildSection(
            '7. Data Retention',
            'We keep your data for as long as your account is active. If you delete your account, we will remove your personal information from our active database within 30 days. Some anonymized data may be retained for statistical or operational purposes but will not be linked to your identity.\n\nVerification documents will be deleted within the same 30-day window following account deletion.',
          ),
          _buildSection(
            '8. Your Rights Under RA 10173',
            'As a data subject under the Philippine Data Privacy Act, you have the following rights with respect to your personal information held by KAYA.\n\nYou have the right to be informed about what data we collect and how we use it. You have the right to access the personal information we hold about you. You have the right to correct any inaccurate or incomplete information. You have the right to request the deletion or blocking of your data in certain circumstances. You have the right to object to the processing of your data. You have the right to data portability, meaning you can request a copy of your data in a usable format.\n\nTo exercise any of these rights, you can contact us through the app or through the contact information provided below. We will respond within a reasonable period and in compliance with applicable law.',
          ),
          _buildSection(
            '9. Cookies and App Permissions',
            'KAYA may request access to your device camera for uploading your profile photo, ID, and selfie during verification. We may also request access to your photo gallery for the same purposes. These permissions are optional and only used when you actively choose to upload an image. You can manage app permissions through your phone settings at any time.',
          ),
          _buildSection(
            '10. Children Privacy',
            'KAYA is not intended for anyone under the age of 18. We do not knowingly collect personal information from minors. If we become aware that a minor has created an account, we will deactivate it and delete the associated information promptly.',
          ),
          _buildSection(
            '11. Changes to This Policy',
            'We may update this privacy policy as the app evolves. If we make material changes, we will notify you through the app before they take effect. We encourage you to review this policy periodically so you always know how your information is being handled.',
          ),
          _buildSection(
            '12. Contact Us',
            'If you have questions about this privacy policy, want to exercise your data rights, or need to report a concern, please reach out to the KAYA development team through the in-app support feature.',
          ),
          const SizedBox(height: 60), // Extra space for scroll indicator
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}
