/// The Terms and Privacy Policy text, in one place.
///
/// Both surfaces that show these documents read from here: the consent sheet at
/// sign-up, and the read-only screen reached from the profile. They were
/// previously the same widget, which meant reading the privacy policy required
/// scrolling two tabs to the bottom and accepting terms you had already
/// accepted. Keeping the text in one place lets the two behave differently
/// without drifting apart.
library;

class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;
}

class LegalDocuments {
  const LegalDocuments._();

  /// Shown on both surfaces. Update whenever the text below changes — a policy
  /// with no date gives the reader no way to tell whether it is current.
  static const String lastUpdated = 'August 2026';

  static const LegalDocument terms = LegalDocument(
    title: 'Terms and Conditions',
    sections: [
      LegalSection(
        'Who Can Use KAYA',
        'KAYA is open to anyone who is at least 18 years old and a resident of the Philippines. You need to be the person you say you are. Creating an account on behalf of someone else, or using false information to sign up, is not allowed and will result in your account being removed.\n\nOne person, one account. If we find duplicate accounts belonging to the same person, we reserve the right to merge or deactivate them.',
      ),
      LegalSection(
        'What KAYA Is',
        'KAYA is a marketplace platform. We connect skilled workers in the trades with individuals and businesses that need their services. We are the bridge, not the employer or the client. What happens between workers and employers after they connect through KAYA is a matter between those two parties.\n\nWe do not guarantee employment. We do not guarantee the quality of work performed. We do not handle payments between workers and employers. We exist to make the connection possible.',
      ),
      LegalSection(
        'Creating Your Profile',
        'When you set up your profile, you are expected to be honest. The information you provide, whether it is your skills, your work history, your certifications, or your contact details, should be accurate and up to date. Misleading other users through your profile is a violation of these terms.\n\nWorkers who claim certifications or licenses they do not actually hold are putting people at risk. If we receive reports or find evidence that a worker has submitted fake credentials, the account will be permanently banned and the matter may be reported to the appropriate authorities.',
      ),
      LegalSection(
        'Verified Badge',
        'The verified badge on KAYA means that our admin team has reviewed and confirmed your identity using the documents you submitted. It does not mean we have tested your skills, observed your work, or vouched for the quality of your services.\n\nGetting verified requires completing three steps: confirming your email address through a one-time code, verifying your phone number through a text message code, and submitting a government-issued ID along with a selfie holding that ID for admin review.\n\nWe reserve the right to revoke the verified status of any account at any time if we have reason to believe the submitted documents were fraudulent or if the account has been flagged for misconduct.',
      ),
      LegalSection(
        'Employer Responsibilities',
        'If you are posting jobs on KAYA, the jobs must be real, legal, and fairly described. You cannot post job listings that are misleading, that offer unreasonably low compensation without disclosure, or that are intended to exploit workers.\n\nYou are responsible for the hiring decisions you make. KAYA is not liable for any dispute, conflict, or incident that arises from a working arrangement made through the platform.',
      ),
      LegalSection(
        'Worker Responsibilities',
        'If you are offering your services on KAYA, you are responsible for showing up, doing the work you agreed to, and behaving professionally. Any disputes about work quality, incomplete jobs, or payment disagreements are between you and the employer.\n\nYou are also responsible for holding any licenses or certifications required by law for the type of work you offer. KAYA does not verify the legal validity of professional licenses beyond reviewing the documents you submit.',
      ),
      LegalSection(
        'What Is Not Allowed',
        'There are certain things that will get your account removed without warning. These include creating a fake identity, submitting fraudulent credentials or government IDs, harassing or threatening other users through the messaging system, posting job listings for illegal activities, using the platform to scam workers or employers, leaving fake reviews to manipulate ratings, and attempting to move transactions off the platform to avoid any accountability.\n\nWe actively monitor for these behaviors. If you come across someone doing any of the above, please use the report feature.',
      ),
      LegalSection(
        'Reviews and Ratings',
        'After a job interaction, both workers and employers can leave reviews. These reviews should be honest and based on actual experience. Fake reviews, whether positive or negative, are not allowed. If you receive a review you believe is false or malicious, you can report it to our team for review.\n\nWe do not remove reviews simply because someone disagrees with them. We only intervene if there is clear evidence of abuse.',
      ),
      LegalSection(
        'Account Suspension and Termination',
        'We reserve the right to suspend or permanently ban any account that violates these terms. In most cases we will notify you of the reason, but in serious situations such as fraud or harassment, we may act immediately without prior warning.\n\nYou can also delete your own account at any time through the app settings. Deleting your account will remove your profile and personal data in accordance with our privacy policy.',
      ),
      LegalSection(
        'Limitation of Liability',
        'KAYA is a student-developed academic capstone project currently in its testing phase. While we have made every effort to build a reliable and secure platform, we cannot guarantee uninterrupted service or be held liable for any losses, damages, or disputes arising from the use of the app.\n\nBy using KAYA, you acknowledge that you understand this and agree not to hold the development team or affiliated institution liable for any outcome of your use of the platform.',
      ),
      LegalSection(
        'Changes to These Terms',
        'We may update these terms from time to time. If we make significant changes, we will notify you through the app. Continuing to use KAYA after those changes take effect means you accept the updated terms.',
      ),
    ],
  );

  static const LegalDocument privacy = LegalDocument(
    title: 'Privacy Policy',
    sections: [
      LegalSection(
        'Information We Collect',
        'When you create an account, we collect your full name, email address, and password. When you set up your profile, you may also provide your phone number, location, a profile photo, a short bio, and your availability status.\n\nWorkers who choose to build a more detailed profile may also add skills, work experience, and professional certifications or licenses.\n\nWhen you apply for the verified badge, you will be asked to submit a government-issued ID and a selfie holding that ID. These documents are used solely for identity verification and are reviewed only by authorized KAYA administrators.\n\nWe also collect activity data such as job posts you create or apply to, messages you send through the platform, and reviews you give or receive. This helps us keep the platform running properly and allows us to detect misuse.',
      ),
      LegalSection(
        'Why We Collect It',
        'We collect your basic account information to create and manage your account. We collect profile information so other users can find you and understand your background. We collect verification documents to confirm your identity and help build trust between workers and employers on the platform. We collect activity data to operate the app, improve it over time, and investigate any reports of misconduct.\n\nWe do not collect any information we do not need. If you choose not to complete your profile or skip optional fields, you can still use the core features of the app.',
      ),
      LegalSection(
        'How We Store and Protect Your Data',
        'Your data is stored on secured servers. Passwords are encrypted and are never stored in plain text. Verification documents such as your ID and selfie are stored separately with restricted access and are only viewable by admin accounts during the verification review process.\n\nWe use industry-standard security practices to protect your information, but no system is completely immune to risk. If you suspect your account has been compromised, please contact us immediately.',
      ),
      LegalSection(
        'Who We Share Your Data With',
        'We do not sell your personal information to anyone. We do not share it with advertisers.\n\nWhen you apply for a job or post one, other users will be able to see the information on your public profile. This includes your name, profile photo, bio, skills, and rating. Your government ID, exact phone number, and email are not shown to other users unless you explicitly include them in your public profile.\n\nWe use third-party services to operate the platform, specifically for sending email verification codes and SMS one-time passwords. These services receive only the information necessary to perform their function and are bound by their own privacy policies.\n\nIn cases involving fraud, illegal activity, or a valid legal order, we may be required to share information with law enforcement or regulatory authorities.',
      ),
      LegalSection(
        'Verification Documents',
        'We want to be especially clear about how we handle your government-issued ID and selfie because we understand these are sensitive.\n\nYour ID and selfie are submitted for the sole purpose of verifying your identity. They are reviewed manually by our admin team. Once a decision is made, whether your verification is approved or rejected, we retain the documents only for as long as necessary for record-keeping and dispute resolution purposes. You may request the deletion of these documents at any time by contacting us, and we will act on that request within a reasonable timeframe.',
      ),
      LegalSection(
        'Certifications and Licenses',
        'If you upload certificates or licenses to your profile, these become part of your public or semi-public worker profile depending on your settings. We store these files on our servers. We do not independently verify the authenticity of professional certificates beyond confirming that a file was uploaded. It is your responsibility to ensure that the documents you upload are genuine and belong to you.',
      ),
      LegalSection(
        'Data Retention',
        'We keep your data for as long as your account is active. If you delete your account, we will remove your personal information from our active database within 30 days. Some anonymized data may be retained for statistical or operational purposes but will not be linked to your identity.\n\nVerification documents will be deleted within the same 30-day window following account deletion.',
      ),
      LegalSection(
        'Your Rights Under RA 10173',
        'As a data subject under the Philippine Data Privacy Act, you have the following rights with respect to your personal information held by KAYA.\n\nYou have the right to be informed about what data we collect and how we use it. You have the right to access the personal information we hold about you. You have the right to correct any inaccurate or incomplete information. You have the right to request the deletion or blocking of your data in certain circumstances. You have the right to object to the processing of your data. You have the right to data portability, meaning you can request a copy of your data in a usable format.\n\nTo exercise any of these rights, you can contact us through the app or through the contact information provided below. We will respond within a reasonable period and in compliance with applicable law.',
      ),
      LegalSection(
        'Cookies and App Permissions',
        'KAYA may request access to your device camera for uploading your profile photo, ID, and selfie during verification. We may also request access to your photo gallery for the same purposes. These permissions are optional and only used when you actively choose to upload an image. You can manage app permissions through your phone settings at any time.',
      ),
      LegalSection(
        'Children Privacy',
        'KAYA is not intended for anyone under the age of 18. We do not knowingly collect personal information from minors. If we become aware that a minor has created an account, we will deactivate it and delete the associated information promptly.',
      ),
      LegalSection(
        'Changes to This Policy',
        'We may update this privacy policy as the app evolves. If we make material changes, we will notify you through the app before they take effect. We encourage you to review this policy periodically so you always know how your information is being handled.',
      ),
      LegalSection(
        'Contact Us',
        'If you have questions about this privacy policy, want to exercise your data rights, or need to report a concern, please reach out to the KAYA development team through the in-app support feature.',
      ),
    ],
  );
}
