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

  invitations,

  /// A chat thread, or the inbox when there is no id.
  chat,
  messages,

  workerProfile,
  employerProfile,

  verification,

  /// Nothing sensible to open.
  none,
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
  if (type.startsWith('review.')) {
    return audience == 'employer'
        ? NotificationDestination.employerProfile
        : NotificationDestination.workerProfile;
  }

  if (referenceType == 'job' && audience == 'employer') {
    // Expiry goes where extending is. Everything else is about a person, so
    // it goes to that job's applicants.
    if (type.startsWith('job.expir')) return NotificationDestination.manageJobs;

    return referenceId != null
        ? NotificationDestination.applicants
        : NotificationDestination.manageJobs;
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
    _ => NotificationDestination.none,
  };
}
