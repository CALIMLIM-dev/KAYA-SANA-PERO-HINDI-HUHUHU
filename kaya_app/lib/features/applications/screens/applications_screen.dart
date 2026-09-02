import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/realtime_refresh.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/job_provider.dart';
import '../widgets/completion_action.dart';

/*
    My Activity — one rule decides where everything goes.

    The screen splits on a single question: **is someone waiting on a decision,
    or is this work?**

      Shortcuts (the strip at the top)  →  a decision is outstanding
      Tabs (Active / History)           →  work, live or finished

    That is the whole model, and it is what the previous version got wrong. It
    had Applications and Invitations as shortcuts and everything else as tabs,
    which sounds the same but split on *role* instead — so a worker who was
    actually hired had their live job filed under a button labelled
    "Applications" and no tab of their own at all, while the employer beside
    them got a whole "Active Jobs" tab. The two sides of the same marketplace
    were shaped differently for no reason a user could see.

    Under the decision rule both sides come out symmetric:

      Shortcut          Whose move   Shown to
      ----------------  -----------  -------------------------------
      Invitations       yours        worker — an employer asked for you
      Applications      theirs       worker — sent, still unanswered
      Applicants        yours        employer — people waiting on a yes/no

      Tab       Worker sees                  Employer sees
      --------  ---------------------------  --------------------------
      Active    jobs you were hired for      jobs you posted, still running
      History   finished, rejected, gone     closed, completed, cancelled

    A hybrid account holds both sides of each tab at once, so every row is
    stamped `_isJob` and rendered by kind rather than by tab — see _TabBody.

    Nothing here is decoration: each shortcut opens a sheet that acts on the
    thing it counts.
*/
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with RealtimeRefresh {
  /// A worker sitting on this screen sees "accepted" land the moment the
  /// employer taps it — the single most important status change in the app.
  /// Invitations are included because accepting one creates an application.
  @override
  List<String> get refreshOn => const ['application.', 'invitation.', 'job.'];

  @override
  void onRealtimeRefresh() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      bindRealtimeRefresh();
    });
  }

  /*
      Which profiles the last fetch was for.

      _load ran once, from initState, against whatever profiles existed at that
      moment. Finishing employer setup while this screen was alive left it
      holding no jobs and showing an employer an empty History — the providers
      had never been asked, and nothing on this screen was going to ask them
      again. The Consumer rebuilt happily around data that was never fetched,
      which is why it looked like a rendering bug rather than a missing request.

      Recorded as the pair it fetched for, and compared on every build, so
      gaining (or losing) a profile triggers exactly one refetch.
  */
  ({bool worker, bool employer})? _loadedFor;

  Future<void> _load() async {
    if (!mounted) return;
    final appMode = context.read<AppModeProvider>();

    _loadedFor = (worker: appMode.hasWorkerProfile, employer: appMode.hasEmployerProfile);

    // Only fetch the side(s) the account actually has.
    final futures = <Future<void>>[
      if (appMode.hasWorkerProfile)
        context.read<ApplicationProvider>().fetchMyApplications(),
      // Invitations were only reachable by tapping a notification, so a worker
      // who missed it had no way back to them. They belong on the worker's
      // activity beside their applications.
      if (appMode.hasWorkerProfile)
        context.read<InvitationProvider>().fetchMyInvitations(),
      if (appMode.hasEmployerProfile) context.read<JobProvider>().fetchMyJobs(),
    ];

    await Future.wait(futures);
  }

  /*
      Applicants waiting on this employer, per job.

      `application_count` is every application the job ever received, in any
      state — it is what the job card shows, and it is the right number there.
      It is the wrong number for a shortcut that means "people waiting on you":
      a job whose three applicants were all turned down would still wear a 3
      and open onto a list with nobody in it.

      `pending_application_count` is the filtered figure, added to myJobs for
      this. It falls back to the total when the field is absent so the app
      stays correct against a server that has not been updated yet — an
      overcount on an old build, never a phantom badge on a current one.
  */
  static int _pendingApplicants(Map<String, dynamic> job) {
    final pending = job['pending_application_count'];
    if (pending is int) return pending;
    final total = job['application_count'];
    return total is int ? total : 0;
  }

  /// Jobs with someone actually waiting — what the Applicants sheet lists.
  static List<Map<String, dynamic>> _jobsAwaitingReview(List<Map<String, dynamic>> jobs) =>
      jobs
          .where((j) => const {'open', 'in_progress'}.contains((j['status'] ?? '').toString()))
          .where((j) => _pendingApplicants(j) > 0)
          .toList();

  /*
      The worker's applications, in a sheet that stays live.

      This used to build the card list once, from the provider's state at the
      moment the button was tapped, and hand that fixed list to the sheet.
      Marking a job complete or reviewing an employer from inside the sheet
      changed the provider - the count on the button behind it would even be
      right the next time it opened - but the sheet on screen kept showing the
      card exactly as it was, because nothing inside it was listening. The
      action looked like it silently failed.

      Passing a builder instead of a built list means the sheet reads the
      provider itself, on every rebuild, so it reflects a change immediately
      rather than only after being closed and reopened.
  */
  void _openApplications(BuildContext context) {
    _showListSheet(
      context,
      title: 'Applied',
      emptyTitle: 'Nothing waiting',
      emptyBody: 'Applications you send appear here until an employer answers. '
          'Once you are hired, the job moves to Active.',
      itemsBuilder: (context) => context
          .watch<ApplicationProvider>()
          .awaitingReply,
      cardBuilder: (a) => _ApplicationCard(application: a, onChanged: _load),
    );
  }

  /*
      The employer's missing route in.

      A notification saying "3 people applied to your job" deep-linked to the
      applicant list, and that was the only door: miss the notification and
      there was no way to reach your own applicants from anywhere in the app.
      The employer's half of this screen was a job list; the people waiting on
      it were not on it.

      Listed by job rather than as one flat roll of applicants, because
      accepting somebody is a decision about a job — who else applied to *that*
      post is the context you need, and it is what /view-applicants already
      shows. This sheet is the index; that screen is still where the yes or no
      happens.
  */
  void _openApplicants(BuildContext context) {
    _showListSheet(
      context,
      title: 'Pending',
      emptyTitle: 'No one waiting',
      emptyBody: 'When someone applies to a job you posted, they appear here '
          'until you accept or decline them.',
      itemsBuilder: (context) =>
          _jobsAwaitingReview(context.watch<JobProvider>().jobs),
      cardBuilder: (j) => _ApplicantsJobCard(job: j),
    );
  }

  /*
      A popup, matching Applications — not a redirect.

      This briefly skipped the sheet and sent the button straight to
      /my-invitations, on the reasoning that the sheet's cards did nothing but
      point at that screen anyway. That solved the wrong problem: the fix
      needed was to give the card real actions, not to remove the popup the
      Applications button already has. Both buttons open the same kind of
      sheet now, and this one accepts or declines right there — see
      _InvitationCard.
  */
  void _openInvitations(BuildContext context) {
    _showListSheet(
      context,
      title: 'Invited',
      emptyTitle: 'No invitations',
      emptyBody: 'Employers who invite you to a job will show up here.',
      itemsBuilder: (context) => context
          .watch<InvitationProvider>()
          .pending,
      cardBuilder: (i) => _InvitationCard(invitation: i),
    );
  }

  /// One sheet shape for all three, so they read as the same kind of thing.
  void _showListSheet<T>(
    BuildContext context, {
    required String title,
    required String emptyTitle,
    required String emptyBody,
    required List<T> Function(BuildContext) itemsBuilder,
    required Widget Function(T) cardBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The one line of explanation lives here, not on the tile
                    // face — the strip stays a strip, and the sheet says what
                    // list you just opened and whose move it is.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The sheet is named after the button that opened
                          // it and nothing else. An explanatory line under
                          // every title is a manual, not a screen.
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutral900)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      color: AppColors.neutral600,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.neutral200),
              /*
                  Builder, not a fixed widget.

                  This re-runs itemsBuilder on every rebuild of the sheet's own
                  subtree, and Provider schedules that rebuild whenever the
                  watched provider calls notifyListeners — which is exactly
                  what happens right after an action inside a card completes.
                  A plain `children: [...]` computed once, above, could not do
                  that; it was a snapshot rather than a view.
              */
              Expanded(
                child: Builder(
                  builder: (context) {
                    final items = itemsBuilder(context);
                    return items.isEmpty
                        ? _EmptyState(title: emptyTitle, body: emptyBody)
                        : ListView(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [for (final i in items) cardBuilder(i)],
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AppModeProvider, ApplicationProvider, JobProvider,
        InvitationProvider>(
      builder: (context, appMode, applications, jobs, invitations, _) {
        // A profile appeared (or went) since the last fetch — see _loadedFor.
        // Scheduled rather than called inline: this is a build, and asking a
        // provider to fetch during one re-enters notifyListeners.
        final now = (worker: appMode.hasWorkerProfile, employer: appMode.hasEmployerProfile);
        if (_loadedFor != null && _loadedFor != now) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        }

        final tabs = _buildTabs(appMode, applications, jobs);

        if (tabs.isEmpty) return _noProfileState();

        /*
            The shortcut strip: the outstanding decisions for the mode you are
            actually in.

            Gated on effectiveMode, not just on which profiles exist. Those are
            different questions, and using the second for the first is what put
            three shortcuts on one strip: a hybrid account holds both profiles
            permanently, so it got the worker pair and the employer one at
            once, crammed across a phone, no matter which side of the app the
            person was using at the time. The mode toggle is how this app has
            always answered "which hat am I wearing" — unified_home_screen
            gates its own activity cards the same way — and this screen simply
            was not asking.

            Worker mode shows two, employer mode shows one. Nothing has to be
            special-cased for hybrids: they switch, like everywhere else.

            A null count means the provider failed and has nothing cached.
            That renders as an em dash, not a zero: "we could not ask" and
            "nobody is waiting" are different answers, and showing the second
            when the first is true is how an employer misses an applicant.
        */
        final showWorker =
            appMode.hasWorkerProfile && appMode.effectiveMode.showsWorkerSide;
        final showEmployer =
            appMode.hasEmployerProfile && appMode.effectiveMode.showsEmployerSide;

        /*
            One shortcut per side, and the mode toggle decides the side.

            There was a rule here that dropped the sent-applications
            shortcut whenever both sides were on screen, so a hybrid never
            saw more than two. It was solving a problem the app already
            solves: the home screen has a mode toggle, and a hybrid uses it
            to say which side they are working as. Second-guessing that
            here meant a worker-and-employer account silently lost its own
            applications list depending on a mode it had not thought about.
        */

        final shortcuts = <_Shortcut>[
          if (showWorker)
            _Shortcut(
              icon: Icons.mark_email_unread_outlined,
              label: 'Invited',
              count: invitations.errorMessage != null && invitations.invitations.isEmpty
                  ? null
                  : invitations.pending.length,
              yourMove: true,
              onTap: () => _openInvitations(context),
            ),
          if (showWorker)
            _Shortcut(
              icon: Icons.send_outlined,
              label: 'Applied',
              count: applications.errorMessage != null && applications.applications.isEmpty
                  ? null
                  : applications.awaitingReply.length,
              // Sent and unanswered — the employer's move, so no red dot. It
              // is here to be checked, not acted on.
              yourMove: false,
              onTap: () => _openApplications(context),
            ),
          if (showEmployer)
            _Shortcut(
              icon: Icons.how_to_reg_outlined,
              label: 'Pending',
              count: jobs.errorMessage != null && jobs.jobs.isEmpty
                  ? null
                  : _jobsAwaitingReview(jobs.jobs).fold<int>(
                      0, (sum, j) => sum + _pendingApplicants(j)),
              yourMove: true,
              onTap: () => _openApplicants(context),
            ),
        ];

        return DefaultTabController(
          // Keyed on the tab set so the controller is rebuilt if the user
          // creates their second profile while this screen is alive.
          key: ValueKey(tabs.map((t) => t.label).join('|')),
          length: tabs.length,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('My Activity',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              /*
                  The strip lives above the tabs, in the header.

                  It was the first thing in the body, directly under the tab
                  bar — which put a screen-level control inside the region the
                  tabs own, so it read as part of whatever tab was selected
                  rather than as something belonging to the whole screen. It
                  also sat still while the list under it changed tabs, which
                  is the one behaviour that makes tab content look broken.

                  Above the divider it is unambiguous: title, your outstanding
                  decisions, then the tabs and their content. It gains from the
                  contrast too — a white card on the primary blue is the most
                  visible position on the screen, which is what a shortcut
                  nobody could find needs to be.
              */
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  _tabBarHeight +
                      (shortcuts.isEmpty
                          ? 0
                          : _ShortcutStrip.heightFor(context, shortcuts.length)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shortcuts.isNotEmpty) _ShortcutStrip(items: shortcuts),
                    TabBar(
                      isScrollable: tabs.length > 3,
                      tabAlignment: tabs.length > 3
                          ? TabAlignment.start
                          : TabAlignment.fill,
                      indicatorColor: AppColors.accent,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: [
                        for (final t in tabs)
                          Tab(text: '${t.label} (${t.items.length})'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final t in tabs)
                        _TabBody(
                          tab: t,
                          /*
                              Whichever providers this tab actually draws from.

                              History can hold a hybrid account's applications
                              and jobs together, so checking only one provider
                              left it reporting "loaded" while the other half
                              of its own list was still in flight, or hiding a
                              real error on the half it wasn't looking at.
                          */
                          isLoading: (t.includesJobs && jobs.isLoading) ||
                              (t.includesApplications && applications.isLoading),
                          error: t.includesJobs
                              ? (jobs.errorMessage ?? applications.errorMessage)
                              : applications.errorMessage,
                          onRefresh: _load,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ActivityTab> _buildTabs(
    AppModeProvider appMode,
    ApplicationProvider applications,
    JobProvider jobs,
  ) {
    final hasWorker =
        appMode.hasWorkerProfile && appMode.effectiveMode.showsWorkerSide;
    final hasEmployer =
        appMode.hasEmployerProfile && appMode.effectiveMode.showsEmployerSide;

    final myApplications = applications.applications;
    final myJobs = jobs.jobs;

    String statusOf(Map<String, dynamic> m) => (m['status'] ?? '').toString();

    /*
        Two tabs, and both sides of the account share them.

        This was "Active Jobs | History", where Active Jobs was employer-only
        and a worker got no active tab at all — their live, accepted work sat
        inside the Applications popup, filed with applications they had merely
        sent. So a hired worker opened My Activity and saw nothing but History
        until they thought to press a button, and the Message and Mark as
        complete actions on that job went with it.

        Active now means the same thing to everyone: work that is happening.
        The worker's accepted applications and the employer's running job posts
        are the same fact seen from the two ends, so they belong in the same
        tab, and a hybrid account sees both at once.

        Every row carries `_isJob` — not just History's — because both tabs can
        now hold a mix and a per-tab flag cannot say which kind a row is.
    */
    return [
      _ActivityTab(
        label: 'Active',
        includesApplications: hasWorker,
        includesJobs: hasEmployer,
        emptyTitle: 'Nothing running',
        emptyBody: hasEmployer && hasWorker
            ? 'Jobs you are hired for and job posts you have open appear here'
            : hasEmployer
                ? 'Post a job to start receiving applicants'
                : 'Jobs you are hired for appear here while you work on them',
        items: [
          // Worker side: hired and not finished. Pending applications are not
          // here on purpose — they are the Applications shortcut, because
          // nothing is happening yet.
          if (hasWorker)
            ...applications.liveWork.map((a) => {...a, '_isJob': false}),
          // Employer side: jobs you posted that are still running.
          if (hasEmployer)
            ...myJobs
                .where((j) => const {'open', 'in_progress'}.contains(statusOf(j)))
                .map((j) => {...j, '_isJob': true}),
        ],
      ),

      /*
          Completed folded into History, rather than sitting beside it.

          Finishing successfully and not going anywhere were two different
          "past" tabs, when both answer the same question - "what am I not
          still waiting on?" - and Active (the applications popup, and Active
          Jobs here) already covers what is still live. Splitting the rest in
          two just meant checking a second, usually-empty tab for the one
          thing that mattered: whether a job actually finished.

          Each row is tagged _isJob explicitly, because this tab is the one
          place a hybrid account's applications and jobs sit in the same
          list — see the itemBuilder note on why a single per-tab flag cannot
          answer that.
      */
      _ActivityTab(
        label: 'History',
        includesApplications: hasWorker,
        includesJobs: hasEmployer,
        emptyTitle: 'No history yet',
        emptyBody: 'Finished and past work will appear here',
        items: [
          if (hasWorker)
            ...myApplications
                .where((a) => const {
                      'completed',
                      'rejected',
                      'withdrawn',
                      'cancelled',
                    }.contains(statusOf(a)))
                .map((a) => {...a, '_isJob': false}),
          /*
              Everything that is not active. Named 'closed' alone once, which
              left a hole: the jobs_posts enum also has 'flagged', and a
              flagged job then belonged to no tab at all — an employer whose
              post was pulled for moderation would find it simply gone from
              their own list, with nothing to say where it went or why.

              Nothing sets 'flagged' today, so this is a hole waiting rather
              than one anyone has fallen in. Written as "not open or running"
              so a new terminal status lands here on its own instead of
              vanishing, and completed jobs are included on purpose now
              rather than living in their own tab.
          */
          if (hasEmployer)
            ...myJobs
                .where((j) => !const {'open', 'in_progress'}.contains(statusOf(j)))
                .map((j) => {...j, '_isJob': true}),
        ],
      ),
    ];
  }

  Widget _noProfileState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Activity',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 56, color: AppColors.neutral300),
              const SizedBox(height: 16),
              const Text('Nothing to show yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral600)),
              const SizedBox(height: 8),
              const Text(
                'Set up a worker profile to track applications, or an employer '
                'profile to track the jobs you post.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab's definition and its rows.
class _ActivityTab {
  const _ActivityTab({
    required this.label,
    required this.items,
    this.includesApplications = false,
    this.includesJobs = false,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String label;

  /// Every row carries an `_isJob` flag, stamped where the tab's items are
  /// assembled. There used to be a tab-level `isJobTab` alongside it, from
  /// when Active Jobs was employer-only and therefore uniformly job posts;
  /// both tabs hold a mix now, so the per-row flag is the only answer and the
  /// tab-level one was a second, weaker source of truth.
  final List<Map<String, dynamic>> items;

  /// Whether this tab draws from the applications / jobs provider, so
  /// _TabBody knows which loading and error states apply to it. Both tabs
  /// need both providers for a hybrid account, or the loading state would
  /// only ever reflect one of the two lists underneath it.
  final bool includesApplications;
  final bool includesJobs;

  final String emptyTitle;
  final String emptyBody;
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tab,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  final _ActivityTab tab;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && tab.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && tab.items.isEmpty) {
      return _message(
        icon: Icons.cloud_off,
        title: 'Could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRefresh,
      );
    }

    if (tab.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            _message(icon: Icons.inbox_outlined, title: tab.emptyTitle, body: tab.emptyBody),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tab.items.length,
        // Typed per row, not per tab: a hybrid account's applications and job
        // posts sit in the same list on both tabs now, so the only reliable
        // answer is the flag stamped on the row itself.
        itemBuilder: (_, i) {
          final row = tab.items[i];
          final isJob = row['_isJob'] as bool? ?? false;
          return isJob
              ? _JobPostCard(job: row, onChanged: onRefresh)
              : _ApplicationCard(application: row, onChanged: onRefresh);
        },
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.neutral300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.neutral400)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Worker side — a job you applied to.
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onChanged});

  final Map<String, dynamic> application;

  /// Called after a completion is recorded, so the list reloads and both cards
  /// pick up the new timestamps.
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final job = application['job'] as Map<String, dynamic>?;
    final employer = job?['employer'] as Map<String, dynamic>?;
    final status = (application['status'] ?? '').toString();

    /*
        Two-sided completion, worker's side.

        The employer used to decide alone and this application flipped to
        completed underneath the worker with no say in it. Now each side
        confirms, and the work is only done when both have.
    */
    final iConfirmed = application['worker_completed_at'] != null;
    final theyConfirmed = application['employer_completed_at'] != null;
    final isHired = status == 'accepted' || status == 'completed';
    final workDone = status == 'completed';

    final canConfirm = isHired && !workDone && !iConfirmed;

    /*
        Dual review, from the worker's side.

        The button used to appear on every completed job whether or not a
        review had already been left, so a second tap produced a 422 the user
        could do nothing about. And nothing ever said the employer had reviewed
        them — which is the half that makes people finish theirs.

        What their review actually says stays hidden until this side writes one.
        Reading it first and answering in kind is how a rating system turns into
        a negotiation.
    */
    final iReviewed = application['i_reviewed_them'] == true;
    final theyReviewed = application['they_reviewed_me'] == true;

    final canReview = workDone && employer != null && !iReviewed;

    final String? reviewNote = !isHired
        ? null
        : !workDone
            // Completion first — the review note would be noise before there is
            // anything to review.
            ? (iConfirmed
                ? 'Marked done · waiting for the employer to confirm'
                : theyConfirmed
                    ? 'The employer marked this done — confirm to finish it'
                    : null)
            : iReviewed && theyReviewed
                ? 'You both reviewed each other'
                : iReviewed
                    ? 'Review sent · waiting for theirs'
                    : theyReviewed
                        ? 'They reviewed you — yours unlocks theirs'
                        : null;

    // The worker's way into the thread, matching the employer's on the
    // applicant list. Before this the only route was the Messages tab, so one
    // direction of the same conversation was a tap and the other was a hunt.
    //
    // Null until the application is accepted — messaging unlocks on hire, so
    // there is genuinely nothing to open before that.
    final conversationId = application['conversation_id'] as int?;
    final canMessage = conversationId != null && employer != null;

    return _cardShell(
      title: (job?['title'] ?? 'Job').toString(),
      subtitle: (employer?['name'] ?? 'Employer').toString(),
      status: status,
      trailing: null,
      note: reviewNote,
      noteIsCompletion: isHired && !workDone,
      // Completion comes before reviewing, and they never both apply — you
      // cannot review work that is not finished — so one slot serves both.
      actionIcon: canConfirm ? Icons.check_circle_outline : Icons.star_outline,
      onMessage: !canMessage
          ? null
          : () => Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'conversationId': conversationId,
                  'name': (employer['name'] ?? 'Employer').toString(),
                  'jobTitle': (job?['title'] ?? 'Job').toString(),
                  'jobId': job?['id'],
                  'otherUserId': employer['id'],
                  'isVerified': (employer['is_verified'] as bool?) ?? false,
                  'applicationId': application['id'],
                  'jobStatus': job?['status'],
                  'myRole': 'worker',
                  'otherRole': 'employer',
                },
              ),
      actionLabel: canConfirm
          ? 'Mark as complete'
          : canReview
              ? 'Review employer'
              : null,
      onAction: canConfirm
          ? () => confirmCompletion(
                context, application['id'] as int, 'employer', onChanged)
          : !canReview
              ? null
              /*
                  Awaited, and refreshed on success.

                  This pushed the review screen and forgot about it, so the
                  Review button was still sitting there when the user came
                  back - the submit had gone through, but nothing here knew to
                  ask the provider again. It could be tapped a second time,
                  and only the server's own "already reviewed" refusal stopped
                  a real duplicate. leave_review_screen pops true on success;
                  this is the one place that was not reading it.
              */
              : () async {
                  final done = await Navigator.pushNamed(
                    context,
                    '/leave-review',
                    arguments: {
                      'revieweeId': employer['id'],
                      'revieweeName':
                          (employer['name'] ?? 'Employer').toString(),
                      'revieweeRole': 'employer',
                      'jobId': job!['id'],
                      'jobTitle': (job['title'] ?? 'this job').toString(),
                    },
                  );
                  if (done == true) await onChanged();
                },
      onTap: job == null
          ? null
          : () => Navigator.pushNamed(context, '/job-details',
              arguments: {'jobId': job['id']}),
    );
  }
}

/// Employer side — a job you posted.
class _JobPostCard extends StatelessWidget {
  const _JobPostCard({required this.job, required this.onChanged});

  final Map<String, dynamic> job;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final applicants = job['application_count'] ?? 0;
    final status = (job['status'] ?? '').toString();

    /*
        Complete and review, on the job card itself.

        Both used to live three taps in — My Jobs, then Manage, then Applicants,
        and only then a Review button — which is why nobody found them. This
        card is where an employer looks when they think "that job is done", so
        this is where the buttons belong.

        Only when exactly one person was hired: with two, the card cannot say
        who you mean, so those still go through the applicants list. The server
        sends `hire` as null in that case rather than picking one.
    */
    final hire = job['hire'] as Map<String, dynamic>?;

    final iConfirmed = hire?['employer_completed_at'] != null;

    /*
        The worker's side of the confirmation, which this card never read.

        The worker's own card has always had both halves — it says "waiting for
        the employer" after they confirm, and "the employer marked this done"
        when the employer goes first. This one only ever had the first half, so
        an employer whose worker had already finished saw a bare Mark as
        complete button with nothing explaining that somebody was waiting on
        them. The information was in the payload the whole time and simply was
        not being looked at.
    */
    final theyConfirmed = hire?['worker_completed_at'] != null;
    final workerName = (hire?['worker_name'] ?? 'the worker').toString();

    final workDone = hire?['status'] == 'completed';
    final canConfirm = hire != null && !workDone && !iConfirmed;
    final canReview = hire != null && workDone && hire['i_reviewed_them'] != true;

    final String? note = hire == null
        ? null
        : !workDone
            ? (iConfirmed
                ? 'Marked done · waiting for $workerName to confirm'
                : theyConfirmed
                    ? '$workerName marked this done — confirm to finish it'
                    : null)
            : hire['i_reviewed_them'] == true
                ? 'You reviewed $workerName'
                : null;

    /*
        The employer's way into the thread, matching the worker's.

        myJobs has returned conversation_id on the hire all along and this
        card never read it, so the worker's card offered Message on a hire
        and the employer's did not — the same conversation, reachable from
        one end only. It also left the two cards visibly different: one row
        with an outlined button beside a filled one, the other with a lone
        filled button stretched across the card.
    */
    final conversationId = hire?['conversation_id'] as int?;

    return _cardShell(
      title: (job['title'] ?? 'Job').toString(),
      subtitle: (job['location'] ?? '').toString(),
      status: status,
      trailing: '$applicants applicant${applicants == 1 ? '' : 's'}',
      note: note,
      noteIsCompletion: hire != null && !workDone,
      onMessage: conversationId == null
          ? null
          : () => Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'conversationId': conversationId,
                  'name': workerName,
                  'jobTitle': (job['title'] ?? 'Job').toString(),
                  'jobId': job['id'],
                  'otherUserId': hire?['worker_id'],
                  'applicationId': hire?['application_id'],
                  'jobStatus': job['status'],
                  'myRole': 'employer',
                  'otherRole': 'worker',
                },
              ),
      actionIcon: canConfirm ? Icons.check_circle_outline : Icons.star_outline,
      actionLabel: canConfirm
          ? 'Mark as complete'
          : canReview
              ? 'Review ${hire['worker_name'] ?? 'worker'}'
              : null,
      onAction: canConfirm
          ? () => confirmCompletion(
                context, hire['application_id'] as int, 'worker', onChanged)
          : !canReview
              ? null
              // Same fix as the worker's card above: awaited, and refreshed
              // on a successful submit so the button does not linger.
              : () async {
                  final done = await Navigator.pushNamed(
                    context,
                    '/leave-review',
                    arguments: {
                      'revieweeId': hire['worker_id'],
                      'revieweeName': (hire['worker_name'] ?? 'Worker').toString(),
                      'revieweeRole': 'worker',
                      'jobId': job['id'],
                      'jobTitle': (job['title'] ?? 'this job').toString(),
                    },
                  );
                  if (done == true) await onChanged();
                },
      onTap: () => Navigator.pushNamed(context, '/view-applicants',
          arguments: {'jobId': job['id']}),
    );
  }
}

Widget _cardShell({
  required String title,
  required String subtitle,
  required String status,
  required String? trailing,
  VoidCallback? onTap,
  /// Optional call to action shown under the card — currently "Review
  /// employer", offered only once a job is completed.
  String? actionLabel,
  VoidCallback? onAction,
  /// Icon on the action button. Defaults to the review star; completion uses a
  /// tick, because a star on "Mark as complete" reads like a rating.
  IconData actionIcon = Icons.star_outline,
  /// Optional "Message" button, shown once a conversation exists. Sits beside
  /// the action when both are present rather than stacking, so an accepted and
  /// completed job does not grow two full-width buttons.
  VoidCallback? onMessage,
  /// Optional one-line state under the buttons — where the completion or the
  /// mutual review stands. A sentence, because a badge cannot say "waiting
  /// for theirs".
  String? note,
  /// Whether that line is about finishing the job rather than reviewing it.
  /// Both used the review icon, so "waiting for the employer to confirm"
  /// was announced with a pencil-and-paper mark — the icon said review while
  /// the sentence said completion.
  bool noteIsCompletion = false,
}) {
  final (bg, fg, label) = _statusStyle(status);

  return Card(
    elevation: 0,
    /*
        White, explicitly.

        Card with no colour takes the theme's surface, which under Material 3
        is the seed colour blended into the background — so every job and
        application card rendered a faint lilac-grey while the shortcut strip
        beside them, which sets its own white, stayed white. Two panels a shade
        apart with no reason for the difference just reads as grubby.
    */
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.neutral200),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fg)),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.neutral600)),
            ],
            if (onMessage != null || (actionLabel != null && onAction != null)) ...[
              const SizedBox(height: 12),
              /*
                  The two buttons match heights, and their labels never wrap.

                  They were plain Expanded siblings in a Row, so each sized
                  itself and the Row centred them against each other. On a
                  360dp phone with the font turned up, "Mark as complete"
                  wrapped to two lines while "Message" stayed on one — the
                  filled button came out shorter than the outlined one beside
                  it and floated in the middle of it. A pair of buttons on one
                  row at two different heights is the thing that makes a card
                  look thrown together.

                  IntrinsicHeight plus stretch makes both as tall as the
                  taller, and scaling the labels down rather than letting them
                  wrap keeps that height at one line in the first place. The
                  two work together: the label fix handles the common case,
                  the stretch guarantees the alignment whatever the text does.
              */
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (onMessage != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Message', maxLines: 1),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (onMessage != null && actionLabel != null && onAction != null)
                    const SizedBox(width: 8),
                  if (actionLabel != null && onAction != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(actionLabel, maxLines: 1),
                        ),
                        /*
                            Primary blue, not the brand yellow.

                            AppColors.accent is #FFD600 at full strength, and
                            filling a half-width button with it put the
                            loudest colour in the palette on the busiest
                            element of the screen — next to the outlined
                            Message button it read as a warning rather than as
                            the main action, and black-on-yellow is the only
                            place in the app that pairing appears.

                            Filled blue against the outlined blue beside it
                            gives the pair an actual hierarchy: same hue,
                            primary is solid, secondary is outlined. The
                            yellow stays where a brand accent belongs — the
                            tab indicator above.
                        */
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                      noteIsCompletion
                          ? Icons.hourglass_bottom
                          : Icons.rate_review_outlined,
                      size: 14,
                      color: AppColors.neutral400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.neutral600)),
                  ),
                ],
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 15, color: AppColors.neutral400),
                  const SizedBox(width: 6),
                  Text(trailing,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.neutral600)),
                  /*
                      Says the row opens the applicants.

                      The whole card has always been tappable to the applicant
                      list, but nothing showed it, so the only place people
                      found their applicants was the separate manage-jobs
                      screen. A label and a chevron make the tap target look
                      like one.
                  */
                  if (onTap != null) ...[
                    const Spacer(),
                    const Text('View',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.primary),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

(Color, Color, String) _statusStyle(String status) => switch (status) {
      'pending' => (
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
          'Pending'
        ),
      'accepted' => (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          'Accepted'
        ),
      'open' => (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success,
          'Open'
        ),
      'in_progress' => (
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary,
          'In Progress'
        ),
      'completed' => (
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary,
          'Completed'
        ),
      'rejected' => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
          'Rejected'
        ),
      'withdrawn' => (
          AppColors.neutral200,
          AppColors.neutral600,
          'Withdrawn'
        ),
      'cancelled' => (
          AppColors.neutral200,
          AppColors.neutral600,
          'Cancelled'
        ),
      'closed' => (AppColors.neutral200, AppColors.neutral600, 'Closed'),
      _ => (AppColors.neutral200, AppColors.neutral600, status),
    };

/// A text-only TabBar's own height. Material's `_kTabHeight`, which is not
/// exported — named here rather than left as a bare 46 in the middle of the
/// header's height sum.
const double _tabBarHeight = 46.0;

/// One outstanding-decision shortcut. See the strip below.
class _Shortcut {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.count,
    required this.yourMove,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// null means the list could not be loaded — rendered as an em dash rather
  /// than a zero, which would claim there is nothing waiting.
  final int? count;

  /// Whether the person looking is the one who has to act. Only these earn the
  /// dot; a sent application is on the employer's desk, not yours, and marking
  /// it urgent would make the signal meaningless on the two that are.
  final bool yourMove;

  final VoidCallback onTap;
}
/*
    The shortcut strip.

    Three designs got binned before this one, and the reasons are worth
    keeping because each was wrong in a different way.

    The first was two outlined pills carrying a yellow count chip with white
    text on it — unreadable, and no room for a third.

    The second was a stat strip: one card, hairline dividers, a big number
    over a small caption. It read fine and it was still wrong, because a
    number over a caption is a *dashboard*. Dashboards are for looking at.
    Nothing about it said "tap me", so a control whose entire purpose was
    being findable still looked like a readout — and a lone employer tile sat
    marooned in the middle of a full-width card.

    This one is shaped like what it is: a button. Icon, the thing it opens,
    and a count badge — the row a person has pressed a thousand times in
    every inbox they have ever used. Side by side when there are two, full
    width when there is one, and roughly half the height of the stat strip,
    because the parts sit on one line instead of stacked.
*/
class _ShortcutStrip extends StatelessWidget {
  const _ShortcutStrip({required this.items});

  final List<_Shortcut> items;

  /*
      How tall the strip will be, before it is built.

      Living in the AppBar means PreferredSize has to declare a height up
      front, and a wrong answer is not a small mistake: too little and the
      strip overflows inside the header, painting the overflow stripe across
      the app bar itself.

      So it is measured, and every text size goes through the viewer's own
      scaler — sizing a header for text scale 1.0 is exactly how this breaks
      for the people who turn their font up, who are the last ones who should
      get a broken screen. Rounded up on purpose: spare pixels are invisible
      blue, missing ones are a yellow stripe.

      One line of content now, so the height is whichever of the icon, the
      label and the badge is tallest — not their sum, which is where the old
      stacked layout spent all its room.
  */
  static double heightFor(BuildContext context, int count) {
    final scaler = MediaQuery.textScalerOf(context);

    const verticalMargin = 8.0 + 6.0;
    const verticalPadding = 8.0 * 2;

    final label = scaler.scale(12) * 1.35;
    final badge = scaler.scale(11.5) * 1.35 + 2;

    var tallest = 16.0;
    if (label > tallest) tallest = label;
    if (badge > tallest) tallest = badge;

    return verticalMargin + verticalPadding + tallest;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _ShortcutButton(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({required this.item});

  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    final count = item.count;
    final waiting = count != null && count > 0;

    /*
        Glass on the blue, not white slabs pasted onto it.

        These were solid white cards sitting in the primary-blue header, and
        two of them turned a clean blue block into a header with foreign
        panels stuck on — the employer activity screen next door has the same
        blue AppBar and reads as one piece, which is the difference that got
        noticed.

        A translucent white fill lets the header colour through, so the
        buttons read as part of it rather than on top of it, and white type on
        blue is the same contrast pairing the title and tabs already use. The
        badge inverts for the one that wants an answer: solid white with the
        number in primary, which is the strongest mark available here and
        needs no red to earn attention.
    */
    final yours = item.yourMove && waiting;

    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withValues(alpha: 0.18),
        highlightColor: Colors.white.withValues(alpha: 0.10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: Colors.white),
                const SizedBox(width: 7),
                /*
                    Scaled down rather than ellipsised.

                    Two buttons across a 320dp phone leave the label about
                    90dp, and the longest of them needs more than that once
                    the system font goes up. An ellipsis would cut the one
                    word that says what the button opens; shrinking keeps it
                    whole, and only bites where it would not otherwise fit.
                */
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: yours
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count == null ? '—' : '$count',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: yours ? AppColors.primary : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _ApplicantsJobCard extends StatelessWidget {
  const _ApplicantsJobCard({required this.job});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final waiting = _ApplicationsScreenState._pendingApplicants(job);
    final location = (job['location'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, '/view-applicants',
              arguments: {'jobId': job['id']}),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('$waiting',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((job['title'] ?? 'Job').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900)),
                      const SizedBox(height: 3),
                      Text(
                        waiting == 1
                            ? '1 person waiting on you'
                            : '$waiting people waiting on you',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.neutral600),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.neutral400)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.neutral400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.neutral300),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.neutral400)),
          ],
        ),
      ),
    );
  }
}

/*
    A pending invitation, with real accept and decline.

    This used to just navigate to /my-invitations - the same list again, on a
    different screen, where accept and decline actually lived - so opening the
    Invitations button and then acting on one was two hops through one list.
    The actions live here now, matching what /my-invitations already does:
    same confirm dialogs, same wording, same "Message" action on the success
    toast once accepted.

    The sheet is reactive (see itemsBuilder in _showListSheet), so a
    successful accept or decline needs nothing extra to make this card
    disappear — the item's status changes, it stops matching "pending", and
    the next rebuild simply does not include it.
*/
class _InvitationCard extends StatefulWidget {
  const _InvitationCard({required this.invitation});

  final Map<String, dynamic> invitation;

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _busy = false;

  Map<String, dynamic>? get _job =>
      widget.invitation['job'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _employer =>
      widget.invitation['employer'] as Map<String, dynamic>?;
  String get _jobTitle => (_job?['title'] ?? 'this job').toString();

  Future<void> _confirmAccept() async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Invitation?'),
        content: Text(
            'Accept the invitation for "$_jobTitle"? You\'ll be able to message the employer after accepting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (accept != true || !mounted) return;

    setState(() => _busy = true);
    final conversationId = await context
        .read<InvitationProvider>()
        .accept(widget.invitation['id'] as int);
    if (!mounted) return;
    setState(() => _busy = false);

    if (conversationId == null) {
      AppToast.error(
        context,
        context.read<InvitationProvider>().errorMessage ??
            'Failed to accept invitation',
      );
      return;
    }

    final employer = _employer;
    final job = _job;
    AppToast.show(
      context,
      'Invitation accepted!',
      type: ToastType.success,
      duration: const Duration(seconds: 4),
      actionLabel: 'Message',
      onAction: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'name': employer?['name'] ?? 'Employer',
          'jobTitle': _jobTitle,
          'jobId': job?['id'],
          'otherUserId': employer?['id'],
          'isVerified': employer?['is_verified'] ?? false,
          'otherRole': 'employer',
        },
      ),
    );
  }

  Future<void> _confirmDecline() async {
    final decline = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Invitation?'),
        content: Text('Decline the invitation for "$_jobTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.neutral600),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (decline != true || !mounted) return;

    setState(() => _busy = true);
    final success = await context
        .read<InvitationProvider>()
        .decline(widget.invitation['id'] as int);
    if (!mounted) return;
    setState(() => _busy = false);

    AppToast.info(
      context,
      success
          ? 'Invitation declined'
          : (context.read<InvitationProvider>().errorMessage ??
              'Failed to decline invitation'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employerName = (_employer?['name'] ?? 'An employer').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_jobTitle,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$employerName invited you to apply',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.neutral600)),
          const SizedBox(height: 12),
          if (_busy)
            const Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _confirmDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral600,
                      side: const BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
