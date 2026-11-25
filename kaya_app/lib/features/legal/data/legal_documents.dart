/// The Terms and the Privacy Policy, in one place.
///
/// Both surfaces that show these documents read from here: the consent sheet at
/// sign-up, and the read-only screen reached from Settings. The website copy is
/// rebuilt from this file by `php artisan kaya:legal-sync`.
///
/// The refund rules are part of the Terms (Barya, Paying for a Top-up,
/// Refunds), not a document of their own: two documents explaining Barya can
/// drift apart and contradict each other.
///
/// Every statement here was checked against the code when it was written
/// (November 2026). Prices are left out on purpose: they are server settings
/// that can change, and the app shows each one before anything is spent.
/// Outside services are described by what they do, not by brand or model.
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

  /// Shown on both surfaces, and recorded with every consent as the version
  /// agreed to. Update whenever the text below changes.
  static const String lastUpdated = '25 November 2026';

  /// The Terms section the Refund Policy rows open on.
  static const String refundsSection = 'Refunds';

  static const LegalDocument terms = LegalDocument(
    title: 'Terms and Conditions',
    sections: [
      LegalSection(
        'Who Can Use KAYA',
        'KAYA is open to anyone who is at least 18 years old and lives in the Philippines. You must be the person you say you are. Creating an account for someone else, or signing up with false information, is not allowed and the account will be removed.\n\nOne person, one account. If we find duplicate accounts belonging to the same person, we may merge or deactivate them.',
      ),
      LegalSection(
        'What KAYA Is, and What It Is Not',
        'KAYA is a marketplace. It connects skilled workers in the trades with the people and businesses that need them. KAYA is the bridge, not the employer and not the client. What happens between a worker and an employer after they connect is between those two people.\n\nKAYA does not:\n- hold, receive or pass on the pay for a job; pay is agreed and settled directly between the employer and the worker;\n- guarantee that you will find work or find a worker;\n- guarantee the quality, safety or result of any work;\n- employ the workers listed in the app.',
      ),
      LegalSection(
        'Worker, Individual and Business Accounts',
        'One account can hold a worker profile, an employer profile, or both. An employer profile is either an individual or a registered business.\n\nA business is verified by its papers rather than by a person\'s ID: it submits a business registration document (a DTI certificate, an SEC registration or a Mayor\'s permit), and the TIN it gives is checked against the BIR\'s public registry. A business cannot post jobs until an admin has approved its documents, and a business account cannot also be a worker account.\n\nYou can remove one profile and keep the other from Settings. An employer profile cannot be removed while it has open job posts.',
      ),
      LegalSection(
        'Verification',
        'Browsing jobs, profiles and the community board does not require verification. These do: posting a job, applying to one, inviting a worker, accepting an invitation, posting or commenting on the community board, claiming free Barya and topping up. To verify, you submit a Philippine government ID and a selfie holding it, and an admin checks them.\n\nThe verified badge means an admin confirmed that the ID matches the person on the account. It is not a guarantee of anyone\'s skill, honesty or reliability. Once verified, the name on your account can no longer be changed.',
      ),
      LegalSection(
        'Documents You Upload',
        'Before you send an ID and selfie, a business document, a certificate or a license, you tick a box confirming that it is yours and true, and that you agree to these terms and the Privacy Policy. KAYA records when you ticked it and which version of these terms you were shown.\n\nA fake or borrowed document ends the account for good. KAYA does not check that a certificate or license is genuine beyond an admin looking at it when it is reported; other users see that it was uploaded, not that it was confirmed.',
      ),
      LegalSection(
        'Your Account and Recovery',
        'Keep your password to yourself. The email address on your account is how you get back in: once you confirm it in Settings, it can receive a code to reset your password. KAYA sends codes by email only.\n\nA code works once and only for a short time. Never share it with anyone; KAYA will never ask you for a code. Codes can be requested once a minute and up to five times an hour. When your password changes, we tell you in the app and by email, so a change you did not make does not go unnoticed.',
      ),
      LegalSection(
        'Your Profile',
        'Everything you put on your profile must be true and about you. Skills, work history, certificates and licenses you add are shown to other users.',
      ),
      LegalSection(
        'Employer Responsibilities',
        'Post only real work that you intend to hire for, with an honest description, location, pay and at least one real photo of the work. Reply to applicants within a reasonable time. Pay the worker the amount and in the way you agreed. Treat the people you hire with respect. Do not ask a worker to do anything unsafe or illegal. Do not use KAYA to collect personal information for any purpose other than the job.',
      ),
      LegalSection(
        'Worker Responsibilities',
        'Apply only to jobs you can actually do and intend to do. Show up when you agreed to, or say so in the chat as early as you can. Do the work to the standard you described. Do not claim skills, experience, certificates or licenses you do not have. Do not share another person\'s details or location with anyone.',
      ),
      LegalSection(
        'Job Location and Location Sharing',
        'Until a worker is hired, a job shows only a circle over its barangay or town, never its exact place. The exact address and map pin go to the employer and the worker they hire.\n\nInside a chat, either side can propose a day and time and the other can accept or decline. An accepted schedule sets the day the work is due. A day a worker has already agreed to with someone else is shown as busy to other employers without saying whose work it is.\n\nDuring a job in progress, a worker can choose to share their live location with the employer, and can stop at any time. Location is shared only with that employer and only while sharing is on.',
      ),
      LegalSection(
        'Completing a Job',
        'When the work is done, the worker and the employer each mark it complete. Before the day the work is due, a job is complete only once both have. A week after that day, a job one side marked complete and the other did not answer counts as complete; a job neither side marked closes as not completed, and that counts on the record of both people. If a job was marked complete but the work did not happen, use Report a Problem on the hire.\n\nReviews can be left only on a completed job.',
      ),
      LegalSection(
        'Chats and the Community Board',
        'A chat opens between an employer and a worker once the worker is hired. When a job is complete, its chat is archived for both people; it comes back if they work together again. Be honest and civil.\n\nChats, comments, job posts and reviews are checked automatically, first by a word filter and then by an automated safety check that reads any language. Offensive words, contact details and moving to another app are hidden; harassment, threats, scams and sexual content are hidden and sent to the KAYA team as a report. The safety check never gives a violation by itself; a person decides.\n\nThe community board is public to every signed-in user. Workers post that they are available; employers and verified businesses post that they are hiring. Every post is read by KAYA before it goes up, runs for a set number of days paid in Barya, and is answered in the open, in comments under the post, through the same filter as the chat.',
      ),
      LegalSection(
        'KAYA Support',
        'Support is answered first by KAYA Assistant, an automated helper. It can read your own account details, such as your verification, any suspension and your Barya balance, to answer you, but it never changes anything on your account. You can ask for a person from the KAYA team at any time, and you can report an answer that is wrong. Support stays open to a suspended account.\n\nSomething\'s Broken sends a bug report to the team. Posted notices about known problems are shown at the top of the support chat.',
      ),
      LegalSection(
        'Barya',
        'Barya is KAYA\'s credit. Every account can claim free Barya when it starts and again each month, earns some when it earns a badge, and can top up for more. Barya has no cash value, cannot be withdrawn, transferred to someone else or exchanged for money, and a refund of Barya is always made in Barya.\n\nIt is spent on: applying to a job, inviting a worker, keeping a job post up past its free first week, boosting a job post or a worker profile, and posting on the community board. The price is shown in the app before you confirm any spend, and prices may change. Barya left in an account when it is deleted is forfeited.',
      ),
      LegalSection(
        'Paying for a Top-up',
        'You pay for a top-up by scanning KAYA\'s GCash QR and paying the exact price of the package, then sending the GCash reference number and a screenshot of the receipt. The Barya is added at once, and the KAYA team then checks the payment against KAYA\'s GCash history.\n\nIf the payment is not found, the Barya is taken back, up to what is left in the wallet, and the account can be given a violation. Sending a reference number for a payment you did not make is fraud and leads to a permanent ban. Only a verified account can top up, and a new top-up waits until the last one is checked.',
      ),
      LegalSection(
        'Refunds',
        'Barya comes back to your wallet, without you asking, when:\n- you withdraw an application within an hour of applying;\n- the employer deletes or closes the job while your application is still pending;\n- somebody else completes the job while your application is still pending;\n- the job post reaches its end date while your application is still pending;\n- KAYA closes the job post while your application is still pending;\n- the employer deletes their account while your application on their open job is still pending;\n- your community post is not approved;\n- you withdraw your community post before it goes up.\n\nBarya is not returned when:\n- an application is rejected, or withdrawn more than an hour after applying;\n- a boost has run, or a job post has used the days paid for;\n- a job post\'s dates are shortened after posting;\n- a community post that is already up is taken down by its poster;\n- an account is deleted.\n\nEach refund shows in your wallet history, and a charge is never refunded twice. Free Barya is never exchanged for anything.\n\nA top-up paid twice or for the wrong amount: write to KAYA Support with the GCash reference number. A payment KAYA received but did not credit is credited or sent back to your GCash. Barya already spent cannot be returned as money. If Barya was taken for something that did not happen, write to KAYA Support and say what you were doing and when; an admin can return it.\n\nKAYA does not receive or hold the pay for a job, so it cannot refund it.',
      ),
      LegalSection(
        'What Is Not Allowed',
        'Fake accounts or fake documents. Applying to or posting jobs you do not intend to act on. Harassment, threats, discrimination or abuse. Scams, fraud, or asking for money in advance for work not done. Sending a GCash reference number for a payment you did not make. Offering or asking for work that is illegal. Collecting other users\' contact details for spam. Attempting to get around Barya charges, the verification rules, the chat filter, or the app\'s limits. Any of these can end your account.',
      ),
      LegalSection(
        'Reports, Violations and Appeals',
        'You can report someone from their profile, a job post, a chat, a community post or comment, or a review about you, with up to three photos as evidence. The report keeps a copy of the message, post or profile it is about, so deleting it afterwards does not erase it. A report from a chat keeps a copy of the last ten messages the reported person sent in your chats with them.\n\nThe person reported is not told who reported them. An admin decides; the outcome may be no violation, a warning, or a suspension for a set time or for good. The person who reported is told the outcome; the person reported hears of it only if a violation is given, and can appeal it within 30 days from Account Status, with up to three photos. A suspended account can still open Account Status, appeal and write to KAYA Support.',
      ),
      LegalSection(
        'Disputes Between Users',
        'A disagreement about pay, quality or attendance is between the worker and the employer, because KAYA is not a party to the job and does not hold any money. KAYA can act on a report when someone breaks these terms, but it cannot make anyone pay or redo work. Settle it directly, or through the barangay or the proper authorities.',
      ),
      LegalSection(
        'Reviews and Ratings',
        'After a job is complete, each side may review the other once, for a limited time. A review must be about the job and cannot be edited after it is sent. Reviews that break these terms can be hidden by an admin, and the rating is recalculated without them.',
      ),
      LegalSection(
        'Account Suspension and Deletion',
        'We may suspend or remove an account that breaks these terms, for a fixed period or permanently, and we will say why. Verification documents of a suspended account are kept for the period stated in the Privacy Policy.\n\nYou may delete your account at any time from Settings, except while it is suspended for a set time. Deletion cannot be undone. It is refused while you are hired on a job in progress, or have a worker on one; finish it first. What is removed and what is kept is described in the Privacy Policy.',
      ),
      LegalSection(
        'Limitation of Liability',
        'KAYA is provided as is. To the extent the law allows, KAYA and the people who built it are not liable for any loss arising from work arranged through the app, from another user\'s conduct, from unpaid work, from damage to property, or from the app being unavailable. These terms are governed by the laws of the Republic of the Philippines.',
      ),
      LegalSection(
        'Changes to These Terms',
        'We may update these terms as the app changes. For a significant change we will tell you in the app before it takes effect. Continuing to use KAYA after that means you accept the updated terms. The date at the bottom of this page is when the terms last changed.',
      ),
    ],
  );

  static const LegalDocument privacy = LegalDocument(
    title: 'Privacy Policy',
    sections: [
      LegalSection(
        'Who Is Responsible',
        'KAYA is responsible for the personal information collected through the app and the KAYA website, as the personal information controller under the Data Privacy Act of 2012 (RA 10173). KAYA has a Data Protection Officer, who answers questions about this policy and requests about your data. Reach them through KAYA Support in the app (Settings, Help, Message KAYA Support) and say your message is for the Data Protection Officer.',
      ),
      LegalSection(
        'Information We Collect',
        'Account: your name, email address, password, whether your email is confirmed, and if you sign in with Google, the name, email and picture Google provides. Older accounts may also have a phone number. Passwords and codes are stored scrambled, never as typed.\n\nProfile: your location, profile photo, bio, availability, and for workers your trade, skills, work history, certificates and licenses. For employers, the business name, type, address, TIN and business registration documents.\n\nVerification: a government-issued ID and a selfie holding it.\n\nConsent records: when you ticked the box before sending a document, and which version of the Terms you were shown.\n\nActivity: jobs you post (with their photos) or apply to, invitations, hires, schedules, reviews, community posts, comments and likes, Barya balance and transactions, GCash top-ups with their reference number and receipt screenshot, reports you make or receive with their photos, appeals with their photos, notifications, and the messages you send in chats.\n\nSupport: your messages to KAYA Support, answers from KAYA Assistant that you report, and bug reports you send from Something\'s Broken: what happened, where, your note, any screenshot you attach, the app version, your phone\'s model and Android version, and the errors the server recorded on your account in the ten minutes before.\n\nLocation: the place you set on your profile or a job; a map pin if you drop one; and, only during a job where you have turned on location sharing, your live position.\n\nDevice: the app version, which the app sends so it can tell you about updates, the sign-in token stored on your phone, and a scrambled code for your phone, which keeps a banned person from making a new account on it. Notifications are fetched by the app; we do not collect a push token.',
      ),
      LegalSection(
        'Why We Collect It',
        'To create and run your account, to send codes that confirm your email and reset your password, to tell you when your password changes, to show workers and employers to each other, to match jobs by trade, skill and distance, to confirm identities and business registrations, to record Barya and check top-up payments, to send notifications, to decide reports and appeals, to check chats, comments, job posts and reviews for contact sharing, scams, harassment and sexual content, to answer you when you write to support, to find and fix problems you report, and to keep the service working and secure. We do not collect information we do not need for these purposes.\n\nWe process it because you agreed to it when you signed up and when you ticked the box before sending a document, because it is needed to give you the service you asked for, and where the law requires us to keep a record.',
      ),
      LegalSection(
        'Who Can See What',
        'Other users see your public profile: your name, photo, bio, location at the city or barangay level, skills, work history, certificates, licenses, rating, badges, and whether you are verified. Job posts, with their photos, are seen by everyone signed in; the place of an open job is shown only as a circle over its barangay or town, and its exact address and pin go only to the employer and the worker they hire.\n\nNobody sees your ID, selfie, exact address, email, phone number, TIN, business documents, GCash receipts or appeal photos except KAYA admins whose role needs them.\n\nYour live location, when you share it, is seen only by the employer on that job, only while sharing is on. A day you have agreed to work is shown as busy to other employers without saying for whom.\n\nCommunity posts and their comments are visible to every signed-in user. Chats are private to the two people in them. When a message is reported, the report keeps a copy of it for the admin deciding it; a report made from a chat keeps the last ten messages the reported person sent in chats with the reporter. Admins do not read the rest of your chats. Messages are also read by the automated safety check described below.',
      ),
      LegalSection(
        'Who We Share Your Data With',
        'We do not sell your personal information and we do not share it with advertisers.\n\nWe use outside providers to run the service, each receiving only what its job needs:\n- sign-in with Google, which confirms a Google account;\n- GCash, which carries top-up payments to KAYA\'s GCash account;\n- an email service, which sends codes and account notices;\n- map tiles, which receive the map area you look at but not your identity; place names come from the Philippine Standard Geographic Code and the GeoNames dataset;\n- the BIR\'s public registry, which a business\'s TIN is checked against;\n- automated AI services, used for the safety check on chats, comments, job posts and reviews, for KAYA Assistant in support, and to match the skills people type.\n\nFor a safety check, an AI service receives only the text being checked and the same sender\'s last few lines, never your name, profile or photos, and KAYA keeps only the result. KAYA Assistant also reads your own account details (verification, suspension, violations, Barya balance) to answer you. Phone numbers and email addresses are hidden before a support message reaches an AI service.\n\nWe will disclose information when required by law or a lawful order, and to investigate fraud or a threat to someone\'s safety.',
      ),
      LegalSection(
        'Data Sent Outside the Philippines',
        'Some of these providers, including the AI services and the email service, process data on servers outside the Philippines. We send them only what their job needs, as described above, and we use providers that protect the data they receive. By using KAYA you agree to this transfer; you can ask the Data Protection Officer which kinds of data leave the country and why.',
      ),
      LegalSection(
        'Verification Documents',
        'Your ID and selfie, and a business\'s registration documents, are stored separately from the rest of your data with restricted access, are read only by KAYA admins reviewing verification or a report, and are never shown to other users. They are kept while your account exists so that a verification can be checked again if a dispute arises, and are deleted when you delete your account.',
      ),
      LegalSection(
        'Payments',
        'Top-ups are paid with GCash to KAYA\'s GCash account. You send us the GCash reference number and a screenshot of your GCash receipt, and we use them only to check the payment against KAYA\'s GCash history. The screenshot is stored with restricted access and is read only by KAYA admins who handle payments. We keep a record of each top-up: the package, the amount, the date, the reference number and whether it was received, because it is a financial record. KAYA never sees your GCash PIN or balance. KAYA does not handle the pay for a job; that is between the worker and the employer.',
      ),
      LegalSection(
        'How We Store and Protect Your Data',
        'Data is stored on a server in a secured environment. Passwords are hashed and never stored in plain text. IDs, selfies, business documents, GCash receipts and appeal photos are kept on private storage that only the server can read. The admin panel is open only to KAYA administrators, each limited to the parts their role needs, and admin actions are recorded in an audit log. Connections use HTTPS.\n\nNo system is completely immune to risk. If you believe your account has been compromised, change your password from Settings and write to KAYA Support.',
      ),
      LegalSection(
        'If There Is a Data Breach',
        'If a breach puts your personal information at real risk of harm, we will notify the National Privacy Commission and the people affected within 72 hours of learning of it, as the Commission\'s rules require. The notice says what happened, what information was involved, what we are doing about it, and what you can do to protect yourself.',
      ),
      LegalSection(
        'Data Retention',
        'We keep your data while your account is active. Live location: once sharing ends, the trail is deleted at the next daily clean-up, and no position is kept longer than seven days. A chat stays for as long as either person in it has an account; a finished job\'s chat is archived, not deleted. A chat with KAYA Support is cleared from your screen when you leave it, unless you are still waiting for the team or your account is suspended; KAYA keeps a copy for the support team for as long as your account exists. Reports, appeals and their photos are kept with the record of the decision. A code expires within fifteen minutes and is cleared once it is used.\n\nWhen you delete your account, the following are removed at once: your name, email, phone, photos, bio, profiles, skills, work history, certificates, licenses, ID and business documents, consent records, saved jobs, notifications and the scrambled code for your phone. Open job posts are closed and the people who applied get their Barya back; your own pending applications are withdrawn; your community posts end. The following are kept because they are records other people rely on, but no longer identify you: your Barya transaction history and top-up records, the reviews you gave other people, reports, bug reports you sent (with any screenshot), and the admin audit log. Messages you sent stay in the other person\'s chat under the name Deleted account. If the account was banned, scrambled copies of its email, phone number, Google account and phone code are kept, so the ban cannot be avoided with a new account.\n\nRemoving only a worker or employer profile removes what that profile holds. Reviews belong to the account and stay.',
      ),
      LegalSection(
        'Your Rights Under RA 10173',
        'Under the Data Privacy Act of 2012 you have the right to be informed of what we collect and why, to access the personal information we hold about you, to correct it, to object to its processing, to ask for it to be deleted or blocked, to a copy of it in a usable format, to be compensated for damage caused by inaccurate or unlawfully used data, and to complain to the National Privacy Commission.\n\nHow to use them: most of your information can be seen and corrected in the app, on your profiles. To delete everything, use Delete Account in Settings. For anything else, including a copy of your data or an objection, write to the Data Protection Officer through KAYA Support, and we will answer within a reasonable time.',
      ),
      LegalSection(
        'App Permissions',
        'Camera and photos: to upload your profile photo, ID, selfie, job photos, community post photos, GCash receipts, report and appeal photos, and documents. Location: to set your place on the map and, if you choose, to share your live position with an employer during a job. That sharing can run in the background so it continues when the screen is off, and a notification shows while it is on. Notifications: to tell you about applicants, hires, messages and schedules. Clipboard: on a code screen, the app looks for a six-digit code you copied, such as from an email, and offers to paste it; nothing on your clipboard is sent anywhere. Each permission is asked for when it is first needed and can be withdrawn in your phone\'s settings.',
      ),
      LegalSection(
        'Children',
        'KAYA is not for anyone under 18. We do not knowingly collect information from minors. If we learn that a minor has created an account, we will deactivate it and delete its information.',
      ),
      LegalSection(
        'Changes to This Policy',
        'We may update this policy as the app changes. For a significant change we will tell you in the app before it takes effect. The date at the bottom of this page is when the policy last changed.',
      ),
      LegalSection(
        'Contact Us',
        'For questions about this policy, to exercise your rights, or to report a concern, write to the Data Protection Officer through KAYA Support (Settings, Help, Message KAYA Support). To report another user, use Report in the chat or on the post. You can also complain to the National Privacy Commission at privacy.gov.ph.',
      ),
    ],
  );
}
