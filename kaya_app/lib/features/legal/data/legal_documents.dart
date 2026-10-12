/// The Terms, the Privacy Policy and the Refund Policy, in one place.
///
/// Both surfaces that show these documents read from here: the consent sheet at
/// sign-up, and the read-only screen reached from Settings. They were
/// previously the same widget, which meant reading the privacy policy required
/// scrolling two tabs to the bottom and accepting terms you had already
/// accepted. Keeping the text in one place lets the two behave differently
/// without drifting apart.
///
/// Every statement here was checked against the code when it was written
/// (October 2026). Prices are left out on purpose: they are server settings
/// that can change, and the app shows each one before anything is spent.
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
  static const String lastUpdated = 'October 2026';

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
        'Your Profile',
        'Everything you put on your profile must be true and about you. Skills, work history, certificates and licenses you add are shown to other users. KAYA does not check that a certificate or license is genuine beyond confirming that a file was uploaded.',
      ),
      LegalSection(
        'Barya',
        'Barya is KAYA\'s credit. Every account can claim free Barya when it starts and again each month, earns some when it earns a badge, and can top up for more. Barya has no cash value, cannot be withdrawn or transferred, and cannot be exchanged for money.\n\nIt is spent on: applying to a job, inviting a worker, keeping a job post up past its free first week, boosting a job post or a worker profile, and posting on the community board. The price is shown in the app before you confirm any spend, and prices may change. Barya left in an account when it is deleted is forfeited.\n\nWhen Barya is returned, and what happens to a purchase, is set out in the Refund Policy.',
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
        'Inside a chat, either side can propose a day and time and the other can accept or decline. An accepted schedule sets the day the work is due. A day a worker has already agreed to with someone else is shown as busy to other employers without saying whose work it is.\n\nDuring a job in progress, a worker can choose to share their live location with the employer, and can stop at any time. Location is shared only with that employer and only while sharing is on. Once sharing ends, the trail is deleted at the next daily clean-up, and no position is kept longer than seven days.',
      ),
      LegalSection(
        'Completing a Job',
        'When the work is done, the worker and the employer each mark it complete. A job counts as complete only once both have. If one side has not confirmed seven days after the day the work was due, the hire is closed as not completed, and that counts on the record of both people.\n\nReviews can be left only on a completed job.',
      ),
      LegalSection(
        'Chats and the Community Board',
        'A chat opens between an employer and a worker once the worker is hired. When a job is complete, its chat is archived for both people; it comes back if they work together again. Be honest and civil. Chats are read by a filter: offensive words are masked, and a message sharing a phone number, an email address or another app to move the conversation to is refused.\n\nThe community board is public to every signed-in user. Workers post that they are available; employers and verified businesses post that they are hiring. Every post is read by KAYA before it goes up, runs for a set number of days paid in Barya, and is answered in the open, in comments under the post, through the same filter as the chat.',
      ),
      LegalSection(
        'What Is Not Allowed',
        'Fake accounts or fake documents. Applying to or posting jobs you do not intend to act on. Harassment, threats, discrimination or abuse. Scams, fraud, or asking for money in advance for work not done. Offering or asking for work that is illegal. Collecting other users\' contact details for spam. Attempting to get around Barya charges, the verification rules, the chat filter, or the app\'s limits. Any of these can end your account.',
      ),
      LegalSection(
        'Reports and Suspensions',
        'You can report someone from a chat or from a community post, with up to three photos as evidence. The report keeps a copy of the message, post or profile it is about, so deleting it afterwards does not erase it. It does not copy the rest of the conversation.\n\nThe person reported is told the reason and can give their side before a decision is made. An admin decides; the outcome may be no action, a warning, or a suspension for a set time or for good, and both people are told the outcome. A suspended account is signed out until the suspension ends.',
      ),
      LegalSection(
        'Disputes Between Users',
        'A disagreement about pay, quality or attendance is between the worker and the employer, because KAYA is not a party to the job and does not hold any money. KAYA can act on a report when someone breaks these terms, but it cannot make anyone pay or redo work. Settle it directly, or through the barangay or the proper authorities.',
      ),
      LegalSection(
        'Reviews and Ratings',
        'After a job both sides have marked complete, each may review the other once, for a limited time. A review must be about the job and cannot be edited after it is sent. Reviews that break these terms can be hidden by an admin, and the rating is recalculated without them.',
      ),
      LegalSection(
        'Account Suspension and Deletion',
        'We may suspend or remove an account that breaks these terms, for a fixed period or permanently, and we will say why. Verification documents of a suspended account are kept for the period stated in the Privacy Policy.\n\nYou may delete your account at any time from Settings. Deletion cannot be undone. It is refused while you are hired on a job in progress, or have a worker on one; finish it first. What is removed and what is kept is described in the Privacy Policy.',
      ),
      LegalSection(
        'Limitation of Liability',
        'KAYA is provided as is. To the extent the law allows, KAYA and the people who built it are not liable for any loss arising from work arranged through the app, from another user\'s conduct, from unpaid work, from damage to property, or from the app being unavailable. These terms are governed by the laws of the Republic of the Philippines.',
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
        'Account: your name, email address or phone number, password, and if you sign in with Google, the name, email and picture Google provides.\n\nProfile: your location, profile photo, bio, availability, and for workers your trade, skills, work history, certificates and licenses. For employers, the business name, type, address, TIN and business registration documents.\n\nVerification: a government-issued ID and a selfie holding it.\n\nActivity: jobs you post or apply to, invitations, hires, schedules, reviews, community posts, comments and likes, Barya balance and transactions, reports you make or receive, notifications, the messages you send in chats, and your messages to KAYA support.\n\nLocation: the place you set on your profile or a job; a map pin if you drop one; and, only during a job where you have turned on location sharing, your live position.\n\nDevice: the app version, which the app sends so it can tell you about updates, and the sign-in token stored on your phone. Notifications are fetched by the app; we do not collect a push token.',
      ),
      LegalSection(
        'Why We Collect It',
        'To create and run your account, to show workers and employers to each other, to match jobs by trade, skill and distance, to confirm identities and business registrations, to record Barya, to send notifications, to decide reports of misconduct, to answer you when you write to support, and to keep the service working and secure. We do not collect information we do not need for these purposes.',
      ),
      LegalSection(
        'Who Can See What',
        'Other users see your public profile: your name, photo, bio, location at the city or barangay level, skills, work history, certificates, licenses, rating, badges, and whether you are verified. Nobody sees your ID, selfie, exact address, email, phone number, TIN or business documents except KAYA admins.\n\nYour live location, when you share it, is seen only by the employer on that job, only while sharing is on. A day you have agreed to work is shown as busy to other employers without saying for whom.\n\nCommunity posts and their comments are visible to every signed-in user. Chats are private to the two people in them. When a message is reported, the report keeps a copy of that one message for the admin deciding it; admins do not read the rest of your chats.',
      ),
      LegalSection(
        'Who We Share Your Data With',
        'We do not sell your personal information and we do not share it with advertisers.\n\nWe use these providers to run the service, each receiving only what its job needs: Google verifies Google sign-ins and, once paid top-ups open, Google Play will process Barya purchases; an email service sends verification and password reset codes; an SMS service sends phone verification codes; maps are drawn from OpenStreetMap tiles, which receive the map area you look at but not your identity; place names come from the Philippine Standard Geographic Code and the GeoNames dataset. The TIN of a business account is checked against the BIR\'s public registry.\n\nWe will disclose information when required by law or a lawful order, and to investigate fraud or a threat to someone\'s safety.',
      ),
      LegalSection(
        'Verification Documents',
        'Your ID and selfie, and a business\'s registration documents, are stored separately from the rest of your data with restricted access, are read only by KAYA admins reviewing verification or a report, and are never shown to other users. They are kept while your account exists so that a verification can be checked again if a dispute arises, and are deleted when you delete your account.',
      ),
      LegalSection(
        'Payments',
        'Topping up Barya is free while KAYA is in testing. When paid top-ups open, the payment will be taken by Google Play and KAYA will never see your card or e-wallet number. We keep a record of each top-up: the package, the amount, the date and the reference, because it is a financial record. KAYA does not handle the pay for a job; that is between the worker and the employer.',
      ),
      LegalSection(
        'How We Store and Protect Your Data',
        'Data is stored on a server in a secured environment. Passwords are hashed and never stored in plain text. The admin panel is open only to KAYA administrators, each limited to the parts their role needs, and admin actions are recorded in an audit log. Connections use HTTPS.\n\nNo system is completely immune to risk. If you believe your account has been compromised, change your password from Settings and write to KAYA support.',
      ),
      LegalSection(
        'Data Retention',
        'We keep your data while your account is active. Live location: once sharing ends, the trail is deleted at the next daily clean-up, and no position is kept longer than seven days. A chat stays for as long as either person in it has an account; a finished job\'s chat is archived, not deleted.\n\nWhen you delete your account, the following are removed at once: your name, email, phone, photos, bio, profiles, skills, work history, certificates, licenses, ID and business documents, saved jobs and notifications. Open job posts are closed and the people who applied get their Barya back; your own pending applications are withdrawn; your community posts end. The following are kept because they are records other people rely on, but no longer identify you: your Barya transaction history, the reviews you gave other people, reports, and the admin audit log. Messages you sent stay in the other person\'s chat under the name Deleted account.\n\nRemoving only a worker or employer profile removes what that profile holds. Reviews belong to the account and stay.',
      ),
      LegalSection(
        'Your Rights Under RA 10173',
        'Under the Data Privacy Act of 2012 you have the right to be informed of what we collect and why, to access the personal information we hold about you, to correct it, to object to its processing, to ask for it to be deleted or blocked, to a copy of it in a usable format, and to complain to the National Privacy Commission.\n\nHow to use them: most of your information can be seen and corrected in the app, on your profiles. To delete everything, use Delete account in Settings. For anything else, including a copy of your data or an objection, write to KAYA support from Settings, Help & Support, and we will answer there within a reasonable time.',
      ),
      LegalSection(
        'App Permissions',
        'Camera and photos: to upload your profile photo, ID, selfie, job photos, community post photos, report evidence and documents. Location: to set your place on the map and, if you choose, to share your live position with an employer during a job. That sharing can run in the background so it continues when the screen is off, and a notification shows while it is on. Notifications: to tell you about applicants, hires, messages and schedules. Each permission is asked for when it is first needed and can be withdrawn in your phone\'s settings.',
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
        'For questions about this policy, to exercise your rights, or to report a concern, write to KAYA support from Settings, Help & Support. To report another user, use Report in the chat or on the post.',
      ),
    ],
  );

  /*
      Its own document, because the question it answers - "do I get my
      Barya back?" - was a paragraph inside the Terms that was already
      wrong: it promised a refund when a hire cancelled a clashing
      application, which the app stopped doing. Every automatic refund
      below is a CreditLedger::refund() call site.
  */
  static const LegalDocument refunds = LegalDocument(
    title: 'Refund Policy',
    sections: [
      LegalSection(
        'Barya Is Not Money',
        'Barya is credit for use inside KAYA. It has no cash value, cannot be withdrawn, transferred to someone else, or exchanged for money, and a refund of Barya is always made in Barya.',
      ),
      LegalSection(
        'Top-ups While KAYA Is in Testing',
        'Topping up is free while KAYA is in testing. Choosing a package adds the Barya to your wallet at once and no money changes hands, so there is no payment to refund.',
      ),
      LegalSection(
        'When Paid Top-ups Open',
        'Paid top-ups will be bought through Google Play. A request to refund a purchase is handled through Google Play under its refund policy. Barya from a purchase that has already been spent cannot be returned as money.',
      ),
      LegalSection(
        'What KAYA Returns Automatically',
        'Your Barya comes back to your wallet, without you asking, when:\n- you withdraw an application within an hour of applying;\n- the employer deletes the job while your application is still pending;\n- the job post reaches its end date while your application is still pending;\n- KAYA closes the job post while your application is still pending;\n- the employer deletes their account while your application on their open job is still pending;\n- your community post is not approved;\n- you withdraw your community post before it goes up.\n\nEach refund shows in your wallet history, and a charge is never refunded twice.',
      ),
      LegalSection(
        'What Is Not Returned',
        'Barya is not returned when:\n- an application is rejected, or withdrawn more than an hour after applying;\n- a boost has run, or a job post has used the days paid for;\n- a job post\'s dates are shortened after posting;\n- a community post that is already up is taken down by its poster;\n- an account is deleted, which forfeits the Barya left in it.\n\nFree Barya, from the welcome and monthly claims or from badges, is never exchanged for anything.',
      ),
      LegalSection(
        'If Something Went Wrong',
        'If Barya was taken for something that did not happen, write to KAYA support from Settings, Help & Support, and say what you were doing and when. An admin can see your wallet history and can return Barya by hand when the charge was a mistake.',
      ),
      LegalSection(
        'Pay for a Job',
        'KAYA does not receive or hold the pay for a job, so it cannot refund it. Pay is agreed and settled directly between the worker and the employer.',
      ),
    ],
  );
}
