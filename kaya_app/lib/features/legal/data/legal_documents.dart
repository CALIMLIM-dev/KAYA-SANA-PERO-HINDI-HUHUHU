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
  static const String lastUpdated = 'September 2026';

  static const LegalDocument terms = LegalDocument(
    title: 'Terms and Conditions',
    sections: [
      LegalSection(
        'Who Can Use KAYA',
        'KAYA is open to anyone who is at least 18 years old and lives in the Philippines. You must be the person you say you are. Creating an account for someone else, or signing up with false information, is not allowed and the account will be removed.\n\nOne person, one account. If we find duplicate accounts belonging to the same person, we may merge or deactivate them.',
      ),
      LegalSection(
        'What KAYA Is',
        'KAYA is a marketplace. It connects skilled workers in the trades with the people and businesses that need them. KAYA is the bridge, not the employer and not the client. What happens between a worker and an employer after they connect is between those two people.\n\nKAYA does not guarantee that you will find work or find a worker, does not guarantee the quality of any work done, and does not handle the payment for a job. Pay for work is agreed and settled directly between the employer and the worker.',
      ),
      LegalSection(
        'Worker, Individual and Business Accounts',
        'One account can hold a worker profile, an employer profile, or both. An employer profile is either an individual or a registered business.\n\nA business account must submit its registration documents: a DTI certificate for a sole proprietorship or an SEC registration for a corporation or partnership, plus a Mayor\'s permit. The TIN it gives is checked against the BIR\'s public registry. A business cannot post jobs until an admin has approved these, and a business account cannot also be a worker account.',
      ),
      LegalSection(
        'Verification',
        'Posting a job, applying to one, inviting a worker, accepting an invitation and buying barya all require a verified account. To verify, you submit a Philippine government ID and a selfie holding it, and an admin checks them. Browsing jobs and profiles does not require verification.\n\nThe verified badge means an admin confirmed that the ID matches the person on the account. It is not a guarantee of anyone\'s skill, honesty or reliability. Once verified, the name on your account can no longer be changed.',
      ),
      LegalSection(
        'Your Profile',
        'Everything you put on your profile must be true and about you. Skills, work history, certificates and licenses you add are shown to other users. KAYA does not check that a certificate or license is genuine beyond confirming that a file was uploaded.\n\nA resume you upload can be opened only by an employer you have a pending or accepted application with, and only while that application is open.',
      ),
      LegalSection(
        'Barya',
        'Barya is KAYA\'s credit. Every account receives some barya on sign-up and some each month, and can buy more. Barya has no cash value, cannot be withdrawn or transferred, and cannot be exchanged for money. It is spent on: applying to a job, inviting a worker, extending a job post past its first free week, boosting a job post or a worker profile, and posting on the community board.\n\nPrices are shown in the app before you confirm any spend and may change. Barya left in an account when it is deleted is forfeited. Purchased barya is not refundable except as described under Refunds.',
      ),
      LegalSection(
        'Refunds',
        'Barya spent is returned to you in these cases only: you withdraw an application within the grace period shown when you applied; the employer removes the job while your application is still pending; your application is cancelled because the job clashed with a hire you had already accepted; a boost or extension could not be applied because of a fault on our side.\n\nBarya is not returned when an application is rejected, when a job post or boost has run its time, or when you delete your account. Money paid for a barya package is not refunded once the barya has been credited.',
      ),
      LegalSection(
        'Employer Responsibilities',
        'Post only real work that you intend to hire for, with an honest description, location, dates and pay. Reply to applicants within a reasonable time. Pay the worker the amount and in the way you agreed. Treat the people you hire with respect. Do not ask a worker to do anything unsafe or illegal. Do not use KAYA to collect personal information for any purpose other than the job.',
      ),
      LegalSection(
        'Worker Responsibilities',
        'Apply only to jobs you can actually do and intend to do. Show up when you agreed to, or say so in the chat as early as you can. Do the work to the standard you described. Do not claim skills, experience, certificates or licenses you do not have. Do not share another person\'s details or location with anyone.',
      ),
      LegalSection(
        'Scheduling and Location Sharing',
        'Inside a chat, either side can propose a day and time and the other can accept or decline. A day a worker has already agreed to with someone else is shown as unavailable to other employers without saying whose work it is.\n\nDuring a job in progress, a worker can choose to share their live location with the employer, and can stop at any time. Location is shared only with that employer, only while sharing is on, and the trail is deleted after the job.',
      ),
      LegalSection(
        'Chats and the Community Board',
        'Chats open between two people once one has hired the other, or when one answers the other\'s community post. Be honest and civil. The community board is public to every signed-in user: post only that you are looking for work or, as a verified business, that you are hiring. Posts run for a week and cost barya.\n\nIf someone reports a chat or a post, a KAYA admin may read the recent messages in that chat to decide the report.',
      ),
      LegalSection(
        'What Is Not Allowed',
        'Fake accounts or fake documents. Applying to or posting jobs you do not intend to act on. Harassment, threats, discrimination or abuse. Scams, fraud, or asking for money in advance for work not done. Offering or asking for work that is illegal. Collecting other users\' contact details for spam. Attempting to get around barya charges, the verification rules, or the app\'s limits. Any of these can end your account.',
      ),
      LegalSection(
        'Reviews and Ratings',
        'After a job both sides have marked complete, each may review the other once. A review must be about the job and cannot be edited after it is sent. Reviews that break these terms can be hidden by an admin, and the rating is recalculated without them.',
      ),
      LegalSection(
        'Account Suspension and Deletion',
        'We may suspend or remove an account that breaks these terms, for a fixed period or permanently, and we will say why. Verification documents of a suspended account are kept for the period stated in the Privacy Policy.\n\nYou may delete your account at any time from Settings. Deletion cannot be undone. You cannot delete while you are on a job that is not finished; finish or cancel it first. What is removed and what is kept is described in the Privacy Policy.',
      ),
      LegalSection(
        'Limitation of Liability',
        'KAYA is provided as is. To the extent the law allows, KAYA and the people who built it are not liable for any loss arising from work arranged through the app, from another user\'s conduct, from unpaid work, from damage to property, or from the app being unavailable. Disputes between a worker and an employer are between them. These terms are governed by the laws of the Republic of the Philippines.',
      ),
      LegalSection(
        'Changes to These Terms',
        'We may update these terms as the app changes. For a significant change we will tell you in the app before it takes effect. Continuing to use KAYA after that means you accept the updated terms. The date at the top of this page is when the terms last changed.',
      ),
    ],
  );

  static const LegalDocument privacy = LegalDocument(
    title: 'Privacy Policy',
    sections: [
      LegalSection(
        'Information We Collect',
        'Account: your name, email address or phone number, password, and if you sign in with Google, the name, email and picture Google provides.\n\nProfile: your location, profile photo, bio, availability, and for workers your trade, skills, work history, certificates, licenses, resume. For employers, the business name, type, address, TIN and business registration documents.\n\nVerification: a government-issued ID and a selfie holding it.\n\nActivity: jobs you post or apply to, invitations, hires, schedules, reviews, community posts, barya balance and transactions, reports you make or receive, notifications, and the messages you send in chats.\n\nLocation: the place you set on your profile or a job; a map pin if you drop one; and, only during a job where you have turned on location sharing, your live position.\n\nDevice: the app version, and a token that lets us show you notifications.',
      ),
      LegalSection(
        'Why We Collect It',
        'To create and run your account, to show workers and employers to each other, to match jobs by trade, skill and distance, to confirm identities and business registrations, to take and record barya payments, to send notifications, to decide reports of misconduct, and to keep the service working and secure. We do not collect information we do not need for these purposes.',
      ),
      LegalSection(
        'Who Can See What',
        'Other users see your public profile: your name, photo, bio, location at the city or barangay level, skills, work history, certificates, licenses, rating, badges, and whether you are verified. Employers you apply to can also open your resume while your application is open. Nobody sees your ID, selfie, exact address, email, phone number, TIN or business documents except KAYA admins.\n\nYour live location, when you share it, is seen only by the employer on that job, only while sharing is on. A day you have agreed to work is shown as unavailable to other employers without saying for whom.\n\nCommunity posts are visible to every signed-in user. Chats are private to the two people in them; an admin may read the recent messages of a chat that has been reported.',
      ),
      LegalSection(
        'Who We Share Your Data With',
        'We do not sell your personal information and we do not share it with advertisers.\n\nWe use these providers to run the service, each receiving only what its job needs: PayMongo processes barya payments and receives your payment details directly; Google verifies Google sign-ins; an email service sends verification and password reset codes; an SMS service sends phone verification codes; maps are drawn from OpenStreetMap tiles, which receive the map area you look at but not your identity; place names come from the Philippine Standard Geographic Code and the GeoNames dataset. The TIN of a business account is checked against the BIR\'s public ORUS registry.\n\nWe will disclose information when required by law or a lawful order, and to investigate fraud or a threat to someone\'s safety.',
      ),
      LegalSection(
        'Verification Documents',
        'Your ID and selfie, and a business\'s registration documents, are stored separately from the rest of your data with restricted access, are read only by KAYA admins reviewing verification or a report, and are never shown to other users. They are kept while your account exists so that a verification can be checked again if a dispute arises, and are deleted when you delete your account.',
      ),
      LegalSection(
        'Payments',
        'When you buy barya, the payment is taken by PayMongo. KAYA never sees your card or e-wallet number. We keep a record of each purchase: the package, the amount, the date and the payment reference, because it is a financial record. KAYA does not handle the pay for a job; that is between the worker and the employer.',
      ),
      LegalSection(
        'How We Store and Protect Your Data',
        'Data is stored on a server in a secured environment. Passwords are hashed and never stored in plain text. Access to the admin panel is limited to KAYA administrators, is logged, and every admin action is recorded in an audit log. Connections use HTTPS.\n\nNo system is completely immune to risk. If you believe your account has been compromised, change your password from Settings and contact us.',
      ),
      LegalSection(
        'Data Retention',
        'We keep your data while your account is active. Live location pings are deleted within a day of being recorded. A chat stays for as long as either person in it has an account.\n\nWhen you delete your account, the following are removed at once: your name, email, phone, photos, bio, profile, skills, work history, certificates, licenses, resume, ID and business documents, saved jobs and notifications. Open job posts are closed and pending applications ended. The following are kept because they are records other people rely on, but no longer identify you: your barya transaction history, the reviews you gave other people, reports, and the admin audit log. Messages you sent stay in the other person\'s chat under the name Deleted account.',
      ),
      LegalSection(
        'Your Rights Under RA 10173',
        'Under the Data Privacy Act of 2012 you have the right to be informed of what we collect and why, to access the personal information we hold about you, to correct it, to object to its processing, to ask for it to be deleted or blocked, to a copy of it in a usable format, and to complain to the National Privacy Commission.\n\nYou can see and edit most of your information in the app. To delete everything, use Delete account in Settings. For anything else, contact us using the details below and we will act within a reasonable time.',
      ),
      LegalSection(
        'App Permissions',
        'Camera and photos: to upload your profile photo, ID, selfie, job photos and documents. Files: to upload a resume. Location: to set your place on the map and, if you choose, to share your live position with an employer during a job. That sharing can run in the background so it continues when the screen is off, and a notification shows while it is on. Notifications: to tell you about applicants, hires, messages and schedules. Each permission is asked for when it is first needed and can be withdrawn in your phone\'s settings.',
      ),
      LegalSection(
        'Children',
        'KAYA is not for anyone under 18. We do not knowingly collect information from minors. If we learn that a minor has created an account, we will deactivate it and delete its information.',
      ),
      LegalSection(
        'Changes to This Policy',
        'We may update this policy as the app changes. For a significant change we will tell you in the app before it takes effect. The date at the top of this page is when the policy last changed.',
      ),
      LegalSection(
        'Contact Us',
        'For questions about this policy, to exercise your rights, or to report a concern, contact the KAYA team at the support email shown in the Help Center in the app. To report another user, use Report in the chat or on the post.',
      ),
    ],
  );
}
