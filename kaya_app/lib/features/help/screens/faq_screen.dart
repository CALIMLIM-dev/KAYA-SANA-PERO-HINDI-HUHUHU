import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';

/// Questions people actually ask, answered for the app as it is.
///
/// The earlier version described an app that did not exist: phone
/// verification at sign-up, an Apply Now button, a blue checkmark, reviews
/// editable for 24 hours, a support team reachable from a button whose
/// handler was empty. Then it went stale again: top-ups "opened in the
/// browser" long after they were credited at once. Every answer here was
/// checked against the code in October 2026 and names the screen and the
/// button as they are. Prices are left out because they are server settings;
/// the app shows each one before anything is spent.
class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQ {
  const _FAQ(this.question, this.answer);

  final String question;
  final String answer;
}

const _groups = <(String, List<_FAQ>)>[
  ('Accounts', [
    _FAQ('How do I create an account?',
        'Sign up with your email or phone number and a password, or with Google. '
            'Then set up a worker profile, an employer profile, or both.'),
    _FAQ('Can one account both look for work and hire?',
        'Yes. Set up both profiles, then switch with the Worker and Employer buttons '
            'in the search bar on the home screen. The one exception is a registered '
            'business: a company account cannot also have a worker profile.'),
    _FAQ('What does verified mean?',
        'An admin checked a Philippine government ID and a selfie of the person holding it. '
            'A business is verified by its registration paper instead: a DTI certificate, '
            'an SEC registration or a Mayor\'s permit. The badge confirms who someone is, '
            'not how good their work is.'),
    _FAQ('What can I do before I am verified?',
        'Look around: browse jobs, profiles and the community board. Posting a job, applying, '
            'inviting, accepting an invitation, posting or commenting on the board, claiming '
            'free Barya and topping up all need a verified account.'),
    _FAQ('How do I get verified?',
        'Open your worker or employer profile from the Profile tab and go to Verification. '
            'Upload the documents. An admin reviews them and you get a notification either way.'),
    _FAQ('How do I remove a profile or delete my account?',
        'Profile, Settings, then the last row. If you have both profiles you can remove just '
            'one and keep the rest; an employer profile with open job posts has to close them '
            'first. Deleting the account asks for your password and cannot be undone. It is '
            'refused while you are hired on a job in progress or have a worker on one.'),
  ]),
  ('Looking for work', [
    _FAQ('How do I apply for a job?',
        'Open the job and tap Apply Now. The price in Barya is on the button. You get it back '
            'if you withdraw within an hour of applying, or if the job is deleted or its post '
            'ends while you are still waiting.'),
    _FAQ('Where are my applications and invitations?',
        'Home, then My Applications: the jobs you applied to, the ones employers invited you '
            'to, and your history.'),
    _FAQ('What happens when I am hired?',
        'A chat opens with the employer. Agree on the day there: either of you can propose a '
            'schedule and the other accepts it. During the job you can share your live location '
            'with the employer, and stop whenever you like.'),
    _FAQ('What puts my profile higher on an employer\'s list?',
        'Employers see first the workers who have the skills a job asks for, or who work in its '
            'trade. Within that, a fuller profile ranks higher: reviews, jobs done, experience, '
            'certificates and being verified. Topping up does not move you up the list; a boost '
            'puts your profile at the top of the feed for a few days.'),
  ]),
  ('Hiring', [
    _FAQ('How do I post a job?',
        'Tap Post a Job on the home screen. The post stays up from its start date to its end '
            'date. The first week is free; keeping it up longer costs Barya and needs an account '
            'that has topped up. The price shows under the dates as you pick them.'),
    _FAQ('How do I find workers?',
        'Post a job and workers apply, or search for workers by trade and distance and invite '
            'one to a job. Inviting costs Barya, and inviting someone you have hired before costs '
            'less. An account that has topped up also sees the list of matching workers for each job.'),
    _FAQ('Where do I see who applied?',
        'Home, then My Jobs, then Applicants on the job. Each applicant shows their skills, '
            'rating and whether you have hired them before. Accept or reject from there.'),
    _FAQ('Can I hire more than one person for a job?',
        'Yes. Set how many workers the job needs, from one to twenty. The post takes applicants '
            'until every spot is filled, and the Roster lists everyone hired.'),
    _FAQ('How do I change a job I posted?',
        'Home, My Jobs, Manage, then Edit. It is the same form as posting. You pay only for '
            'days or a boost you add.'),
  ]),
  ('Finishing a job', [
    _FAQ('How does a job get marked complete?',
        'When the work is done, you and the other person each tap Mark as Complete. It counts '
            'as complete once both have. If one side has not confirmed seven days after the day '
            'the work was due, the hire closes as not completed, which counts against both.'),
    _FAQ('Which day is the work due?',
        'The end date on the post, or the day agreed in the chat\'s schedule if there is one. '
            'An agreed schedule wins, so a job that finishes early can be completed early.'),
    _FAQ('How do reviews work?',
        'Once a job is complete, each side can review the other once, for a limited time. '
            'A review cannot be edited after it is sent. An admin can hide a review that breaks '
            'the rules.'),
  ]),
  ('Barya and payment', [
    _FAQ('What is Barya?',
        'KAYA\'s credit. Claim free Barya in My Wallet when you start and again each month, and '
            'earn some with badges. Applying, inviting, boosting, keeping a job post up past its '
            'first week and posting on the community board cost Barya. Messaging and commenting '
            'are free. Barya has no cash value.'),
    _FAQ('How do I pay a worker?',
        'Directly. KAYA does not hold or move job payments. Agree the amount and how you will '
            'pay in the chat.'),
    _FAQ('How do I top up?',
        'Profile, My Wallet, then choose a package. While KAYA is in testing, top-ups are free '
            'and the Barya is added at once. You need a verified account.'),
    _FAQ('What does topping up unlock?',
        'A top-up of any size unlocks boosting, keeping job posts up past the free week, the '
            'list of matching workers for your jobs, up to three community posts at a time '
            'instead of one, and your card on an employer\'s Applicants list opening as a resume.'),
    _FAQ('Do I get Barya back?',
        'In set cases, automatically. The Refund Policy in Settings, About & Legal lists them, '
            'and it is linked at the bottom of My Wallet.'),
  ]),
  ('Community board', [
    _FAQ('What is the community board?',
        'The Community tab. Workers post that they are available; employers and verified '
            'businesses post that they are hiring. Anyone signed in can read and like posts, and '
            'verified accounts can ask and answer in the comments under each one.'),
    _FAQ('Why is my post not on the board yet?',
        'Every post is read by KAYA before it goes up, and your paid days start when it is '
            'approved. If it is not approved you are told why and your Barya is returned.'),
    _FAQ('How many posts can I have up?',
        'One at a time, or three once your account has topped up. Posts waiting for review '
            'count toward that.'),
  ]),
  ('Safety and support', [
    _FAQ('How do I report someone?',
        'In a chat, open the menu at the top right and choose Report User; on a community post, '
            'use the menu on the post. You can add up to three photos as evidence. The person is '
            'told the reason and can give their side, an admin decides, and you are told the outcome.'),
    _FAQ('Why was my message refused?',
        'Chats and comments are read by a filter. A phone number, an email address or asking to '
            'move to another app is refused, to keep people from being taken off KAYA and '
            'scammed. Offensive words are hidden and the message still sends.'),
    _FAQ('How do I reach KAYA?',
        'Settings, Help & Support, Message KAYA support, or the button below. Somebody answers '
            'you in that same chat.'),
  ]),
];

class _FAQScreenState extends State<FAQScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(_FAQ item) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return item.question.toLowerCase().contains(q) || item.answer.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final (title, items) in _groups)
        (title, items.where(_matches).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FAQs'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search questions',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nothing matches that. Try fewer or other words, or ask us below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
              ),
            ),

          for (final (title, items) in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final item in items) _tile(item),
            const SizedBox(height: 12),
          ],

          /*
              When the answer is not up there.

              The FAQ covers the questions somebody thought of in advance. A
              rejected verification nobody explained, or barya taken for a
              post that vanished, is not one of them - and until this there
              was nowhere to go but the app store review page.
          */
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Still stuck?',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Write to KAYA and somebody will answer you here.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.neutral600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRouter.support),
                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                    label: const Text('Message KAYA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(_FAQ item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: ExpansionTile(
        // A search narrows the list to a few; open them so the answer is
        // there without another tap.
        key: ValueKey('${item.question}|${_query.isNotEmpty}'),
        initiallyExpanded: _query.isNotEmpty,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          item.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral900,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              item.answer,
              style: const TextStyle(
                fontSize: 13.5,
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
