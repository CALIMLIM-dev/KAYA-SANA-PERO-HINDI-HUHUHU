/*
    Where a notification takes you.

    Every notification carries a reference_type, and the list used to route on
    that alone. Two whole classes of them went to the wrong screen:

      - A review is attached to the job it happened on, so being told you had
        been reviewed opened the public job advert - with an "Application
        pending" button on it, and no review anywhere on the page.

      - Every employer-side notification carrying a job reference opened that
        same public advert: the employer's own listing, as a worker sees it.
        An applicant withdrawing, an invitation accepted, a post a week from
        expiring - all of them landed on a page with an Apply button. "Someone
        applied to your job" was special-cased for exactly this reason years
        ago; the other six never were.

    The rule lives here rather than inside the screen's build so it can be
    tested as a rule. A test that restates the logic instead of calling it is
    two copies of the same decision, which is how the conversation job_id and
    the application tally both drifted from the thing they mirrored.
*/
enum NotificationDestination {
  /// The applicants on one job. Carries the job id.
  applicants,

  /// The employer's own list of posts, where extending lives.
  manageJobs,

  /// The public job page, which is the right page for a worker.
  jobDetails,

  /// The worker's own applications.
  applications,

  /// Work happening now, from either side.
  active,

  invitations,

  /// A chat thread, or the inbox when there is no id.
  chat,
  messages,

  /*
      The public profile - the page somebody else sees when they open you.

      Not the profile tab. Reviews are only ever rendered on the public
      view, so sending a review notification to the account's own profile
      screen opened a page with no review anywhere on it, which reads as
      the tap having done nothing.
  */
  workerProfile,
  employerProfile,

  verification,

  /// A report about this account, to read and answer.
  reportResponse,

  /// A notice on the community board. Carries the post id.
  communityPost,

  /// The account's thread with KAYA support.
  support,

  /// Somebody else's worker profile. Carries their user id.
  person,

  /*
      Nothing to open: a warning, a report's outcome, an announcement.

      Their whole point is the words. Shown in full where the tap happened,
      not by opening the notification list again - which put a second copy
      of it on top of the first, so you backed out twice.
  */
  fullText,
}

/// Which screen a notification belongs on, from what the server sent with it.
NotificationDestination notificationDestination({
  required String type,
  required String audience,
  required String? referenceType,
  int? referenceId,
}) {
  // Checked before reference_type: the notification is about the applicant,
  // not about the advert they answered.
  if (type == 'application.received' && referenceId != null) {
    return NotificationDestination.applicants;
  }

  // A review lives on the reviewed person's own profile, and on the right
  // side of it - an employer reviewed as an employer does not want their
  // worker profile.
  // A badge is drawn in the same place a review is.
  if (type.startsWith('review.') || type.startsWith('badge.')) {
    return audience == 'employer'
        ? NotificationDestination.employerProfile
        : NotificationDestination.workerProfile;
  }

  if (referenceType == 'job' && audience == 'employer') {
    // Expiry goes where extending is, and a post an admin closed is in its
    // History. A hire by invitation goes to My Jobs too: the hired person
    // is on the job's card there, and the applicants list opens on Pending,
    // where they are not. Everything else is about an applicant.
    if (type.startsWith('job.expir') ||
        type == 'job.closed' ||
        type == 'invitation.accepted') {
      return NotificationDestination.manageJobs;
    }

    return referenceId != null
        ? NotificationDestination.applicants
        : NotificationDestination.manageJobs;
  }

  // KAYA answering carries no reference; the thread is one per account.
  if (type.startsWith('support.')) return NotificationDestination.support;

  /*
      Hired, or asked to confirm a finished job. For a worker that is live
      work, on the Active list. For an employer it is the job's card in My
      Jobs, which is where their running posts and Mark as complete are.
  */
  if (type == 'application.accepted' ||
      type == 'application.completion_pending') {
    return audience == 'employer'
        ? NotificationDestination.manageJobs
        : NotificationDestination.active;
  }

  // A finished job waits in Active for the worker's review.
  if (type == 'job.completed' && audience != 'employer') {
    return NotificationDestination.active;
  }

  return switch (referenceType) {
    'job' => NotificationDestination.jobDetails,
    // Both sides get a completion nudge. The employer's copy used to open My
    // Applications - a worker screen, which an employer-only account is then
    // refused entry to.
    'application' => audience == 'employer'
        ? NotificationDestination.manageJobs
        : NotificationDestination.applications,
    'invitation' => NotificationDestination.invitations,
    'conversation' => referenceId != null
        ? NotificationDestination.chat
        : NotificationDestination.messages,
    'verification' => NotificationDestination.verification,
    'report' => referenceId != null
        ? NotificationDestination.reportResponse
        : NotificationDestination.fullText,
    'community_post' => referenceId != null
        ? NotificationDestination.communityPost
        : NotificationDestination.fullText,
    // "Available for work again": the point is the person.
    'user' => referenceId != null
        ? NotificationDestination.person
        : NotificationDestination.fullText,
    _ => NotificationDestination.fullText,
  };
}
