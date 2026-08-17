<?php

namespace App\Services;

use App\Events\Realtime\NotificationPushed;
use App\Models\Application;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Review;
use App\Models\UserNotification;

/**
 * The one place notifications are written.
 *
 * Listeners call these intent-named methods rather than assembling rows
 * themselves, so the audience, wording and reference of a given event are
 * decided once. Getting `audience` wrong is the easy mistake here — a hybrid
 * account is both a worker and an employer, so "who is this for" must be
 * answered from the role the person is playing *in this event*, not from what
 * profiles they happen to own.
 */
class NotificationService
{
    public function __construct(private RealtimeBroadcaster $realtime) {}

    /** Never notify someone about their own action. */
    private function push(
        int $userId,
        string $audience,
        string $type,
        string $title,
        ?string $body = null,
        ?string $referenceType = null,
        ?int $referenceId = null,
        ?int $actorId = null,
    ): ?UserNotification {
        if ($actorId !== null && $actorId === $userId) {
            return null;
        }

        /*
            Respect the switches in settings.

            Checked here rather than in each caller, so a category cannot be
            muted in one place and still arrive from another. Suppression skips
            the row entirely: an unwanted notification should not sit unread in
            the list waiting to be dismissed.
        */
        $recipient = \App\Models\User::find($userId);
        if ($recipient && !$recipient->wantsNotification(UserNotification::categoryFor($type))) {
            return null;
        }

        $notification = UserNotification::create([
            'user_id'        => $userId,
            'audience'       => $audience,
            'type'           => $type,
            'title'          => $title,
            'body'           => $body,
            'reference_type' => $referenceType,
            'reference_id'   => $referenceId,
        ]);

        // Written first, pushed second. The row is the source of truth; the
        // socket is delivery, and RealtimeBroadcaster keeps a Reverb outage
        // from turning a successful hire into a 500.
        $this->broadcast($notification);

        /*
            Delivery to a phone that is not running the app is handled by the
            foreground service, not from here.

            There is no push provider in this project by choice. While a job is
            active the app runs a foreground service that polls for anything
            new and raises it on the notification shade, which covers the window
            where coordination actually matters without depending on a third
            party. Outside that window a notification waits in the list until
            the app is next opened.
        */

        return $notification;
    }

    /**
     * Pushes the new row along with both unread totals.
     *
     * Sending the counts rather than letting the client increment matters for a
     * hybrid account: the badge is per-mode, so a client that only knows "one
     * more notification arrived" cannot tell which badge to move without
     * re-deriving audience rules it shouldn't own.
     */
    private function broadcast(UserNotification $notification): void
    {
        $counts = UserNotification::where('user_id', $notification->user_id)
            ->unread()
            ->selectRaw('audience, COUNT(*) as total')
            ->groupBy('audience')
            ->pluck('total', 'audience');

        $this->realtime->push(new NotificationPushed(
            notification: $notification,
            unreadWorker: (int) $counts->get(UserNotification::AUDIENCE_WORKER, 0),
            unreadEmployer: (int) $counts->get(UserNotification::AUDIENCE_EMPLOYER, 0),
        ));
    }

    /**
     * A hire cancelled other applications that clashed with its dates.
     *
     * Both sides are told, and the employer's half is not a courtesy: their
     * applicant list just got shorter without them touching it, and an
     * unexplained disappearance reads as a bug in the app.
     *
     * @param  \Illuminate\Support\Collection<int, Application>  $clashing
     */
    public function applicationsCancelledByClash(
        Application $accepted,
        \Illuminate\Support\Collection $clashing,
    ): void {
        if ($clashing->isEmpty()) {
            return;
        }

        $hiredTitle = $accepted->job?->title ?? 'another job';
        $count = $clashing->count();

        $this->push(
            userId: $accepted->worker_id,
            audience: UserNotification::AUDIENCE_WORKER,
            type: 'application.cancelled',
            title: $count === 1
                ? '1 application was cancelled'
                : "{$count} applications were cancelled",
            // Says which job caused it and that the rest survived. A worker who
            // is only told "cancelled" has to open every application to find out
            // what they still have.
            body: 'They clashed with the dates for "'.$hiredTitle.'". '
                .'Your other applications are unaffected.',
            referenceType: 'job',
            referenceId: $accepted->job_id,
        );

        foreach ($clashing as $application) {
            $employerId = $application->job?->employer_id;
            if ($employerId === null) {
                continue;
            }

            $this->push(
                userId: $employerId,
                audience: UserNotification::AUDIENCE_EMPLOYER,
                type: 'application.cancelled',
                title: 'An applicant is no longer available',
                body: 'They were hired for work on the same dates as "'
                    .($application->job?->title ?? 'your job').'".',
                referenceType: 'job',
                referenceId: $application->job_id,
            );
        }
    }

    /** A worker applied — tell the employer, in their employer capacity. */
    public function applicationReceived(Application $application): void
    {
        $job = $application->job;
        if (!$job) return;

        $this->push(
            userId: $job->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::APPLICATION_RECEIVED,
            title: 'New applicant',
            body: ($application->worker?->name ?? 'Someone')
                . ' applied to "' . $job->title . '".',
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $application->worker_id,
        );
    }

    public function applicationAccepted(Application $application): void
    {
        $job = $application->job;
        if (!$job) return;

        $this->push(
            userId: $application->worker_id,
            audience: UserNotification::AUDIENCE_WORKER,
            type: UserNotification::APPLICATION_ACCEPTED,
            title: "You're hired",
            body: 'Your application for "' . $job->title . '" was accepted.',
            referenceType: 'application',
            referenceId: $application->id,
            actorId: $job->employer_id,
        );
    }

    public function applicationRejected(Application $application): void
    {
        $job = $application->job;
        if (!$job) return;

        $this->push(
            userId: $application->worker_id,
            audience: UserNotification::AUDIENCE_WORKER,
            type: UserNotification::APPLICATION_REJECTED,
            title: 'Application not selected',
            body: 'You were not selected for "' . $job->title . '".',
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $job->employer_id,
        );
    }

    public function invitationReceived(Invitation $invitation): void
    {
        $job = $invitation->job;
        if (!$job) return;

        $this->push(
            userId: $invitation->worker_id,
            audience: UserNotification::AUDIENCE_WORKER,
            type: UserNotification::INVITATION_RECEIVED,
            title: 'Job invitation',
            body: ($invitation->employer?->name ?? 'An employer')
                . ' invited you to "' . $job->title . '".',
            referenceType: 'invitation',
            referenceId: $invitation->id,
            actorId: $invitation->employer_id,
        );
    }

    public function invitationAccepted(Invitation $invitation): void
    {
        $job = $invitation->job;
        if (!$job) return;

        $this->push(
            userId: $invitation->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::INVITATION_ACCEPTED,
            title: 'Invitation accepted',
            body: ($invitation->worker?->name ?? 'A worker')
                . ' accepted your invitation to "' . $job->title . '".',
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $invitation->worker_id,
        );
    }

    public function invitationDeclined(Invitation $invitation): void
    {
        $job = $invitation->job;
        if (!$job) return;

        $this->push(
            userId: $invitation->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::INVITATION_DECLINED,
            title: 'Invitation declined',
            body: ($invitation->worker?->name ?? 'A worker')
                . ' declined your invitation to "' . $job->title . '".',
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $invitation->worker_id,
        );
    }

    /**
     * The recipient is whichever side of the conversation didn't send it —
     * which is also the capacity they read it in.
     */
    public function messageReceived(Message $message): void
    {
        $conversation = $message->conversation;
        if (!$conversation) return;

        $senderIsWorker = $message->sender_id === $conversation->worker_id;

        $recipientId = $senderIsWorker
            ? $conversation->employer_id
            : $conversation->worker_id;

        $audience = $senderIsWorker
            ? UserNotification::AUDIENCE_EMPLOYER
            : UserNotification::AUDIENCE_WORKER;

        $this->push(
            userId: $recipientId,
            audience: $audience,
            type: UserNotification::MESSAGE_RECEIVED,
            title: 'New message',
            body: ($message->sender?->name ?? 'Someone') . ': '
                . \Illuminate\Support\Str::limit($message->message_text, 80),
            referenceType: 'conversation',
            referenceId: $conversation->id,
            actorId: $message->sender_id,
        );
    }

    /** Job finished — the worker is the one who needs to know. */
    public function jobCompleted(JobPost $job): void
    {
        $workerIds = $job->applications()
            ->where('status', 'accepted')
            ->pluck('worker_id');

        foreach ($workerIds as $workerId) {
            $this->push(
                userId: $workerId,
                audience: UserNotification::AUDIENCE_WORKER,
                type: UserNotification::JOB_COMPLETED,
                title: 'Job completed',
                body: '"' . $job->title . '" was marked complete. You can now leave a review.',
                referenceType: 'job',
                referenceId: $job->id,
                actorId: $job->employer_id,
            );
        }
    }

    /*
        A new job that suits you.

        The retention feature the app was missing: a worker had no way to learn
        a matching job existed except by opening the app and scrolling the feed.
        The scoring already existed — JobMatchService powers the employer's
        "suggested workers" list — so this is the same judgement pointed the
        other way.

        Two deliberate limits, because a notification is far more intrusive than
        a row in a list:

        MIN_NOTIFY_SCORE is set above JobMatchService::MIN_VISIBLE_SCORE. Being
        in the same category (40) is enough to appear in a list, but not enough
        to be worth interrupting someone for — this requires the category plus
        proximity or genuine skill overlap. Otherwise every plumber in the
        province is notified of every plumbing job, and they all turn
        notifications off within a week.

        MAX_RECIPIENTS caps the blast. A job in a busy category could otherwise
        notify hundreds of people at once, which is indistinguishable from spam
        and would make the app the thing that made their phone buzz all day.

        Candidates are pre-filtered in SQL to workers who share the category or
        one of the job's skills — precisely the set that can reach the
        threshold — rather than scoring every profile in the database.
    */
    public const MIN_NOTIFY_SCORE = 45;
    public const MAX_RECIPIENTS = 25;

    /*
        One side pressed "mark as complete"; the other has not.

        The single most important missing notification. Completion needs both
        parties, so until the second one confirms the job sits in a half-state
        — and the person being waited on had no way to know they were being
        waited on. They would open the app days later and find a job still
        showing as active, with no reason given.

        Sent to whichever side has *not* confirmed.
    */
    public function completionPending(Application $application, string $confirmedSide): void
    {
        $application->loadMissing('job');
        $job = $application->job;

        if (! $job) {
            return;
        }

        $employerConfirmed = $confirmedSide === 'employer';

        $recipientId = $employerConfirmed ? $application->worker_id : $job->employer_id;
        $actorId = $employerConfirmed ? $job->employer_id : $application->worker_id;
        $who = $employerConfirmed ? 'The employer' : 'The worker';

        $this->push(
            userId: $recipientId,
            audience: $employerConfirmed
                ? UserNotification::AUDIENCE_WORKER
                : UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::APPLICATION_COMPLETION_PENDING,
            title: 'Confirm the job is done',
            body: $who.' marked "'.$job->title.'" as complete. Confirm to finish it and leave a review.',
            referenceType: 'application',
            referenceId: $application->id,
            actorId: $actorId,
        );
    }

    /**
     * An applicant withdrew.
     *
     * The employer's shortlist just got shorter without them touching it, and
     * an unexplained disappearance reads as a bug in the app.
     */
    public function applicationWithdrawn(Application $application): void
    {
        $application->loadMissing(['job', 'worker']);
        $job = $application->job;

        if (! $job) {
            return;
        }

        $this->push(
            userId: $job->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::APPLICATION_WITHDRAWN,
            title: 'An applicant withdrew',
            body: ($application->worker?->name ?? 'Someone')
                .' withdrew their application for "'.$job->title.'".',
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $application->worker_id,
        );
    }

    /*
        Somebody reviewed you.

        The body deliberately does not quote the review. Reviews are withheld
        until both sides have written one, and a notification that leaked the
        text would walk straight around that rule — the whole point of which is
        that neither party can tailor their review to the one they already
        received.
    */
    public function reviewReceived(Review $review): void
    {
        $this->push(
            userId: $review->reviewee_id,
            audience: $review->reviewee_role === 'worker'
                ? UserNotification::AUDIENCE_WORKER
                : UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::REVIEW_RECEIVED,
            title: 'You have a new review',
            body: 'Someone you worked with left you a review. Write yours to see it.',
            referenceType: 'job',
            referenceId: $review->job_id,
            actorId: $review->reviewer_id,
        );
    }

    /*
        An admin decided on an identity submission.

        The one notification a person genuinely cannot work out for themselves.
        Verification is reviewed by hand, on no fixed schedule, and until now
        the only way to learn the outcome was to reopen the verification screen
        and look — so someone who uploaded an ID and heard nothing could not
        tell whether they had been rejected or simply not reached yet.

        A rejection carries the admin's reason. Without it the notification says
        the submission failed and leaves the person to guess what to change,
        which usually means they submit the same thing again.
    */
    public function verificationApproved(int $userId, string $audience): void
    {
        $this->push(
            userId: $userId,
            audience: $audience,
            type: UserNotification::VERIFICATION_APPROVED,
            title: 'You are verified',
            body: 'Your identity check passed. The verified badge now shows on your profile.',
            referenceType: 'verification',
            referenceId: null,
        );
    }

    public function verificationRejected(int $userId, string $audience, ?string $reason): void
    {
        $this->push(
            userId: $userId,
            audience: $audience,
            type: UserNotification::VERIFICATION_REJECTED,
            title: 'Verification was not approved',
            body: $reason === null || $reason === ''
                ? 'Your identity check was not approved. You can submit again from your profile.'
                : $reason.' You can submit again from your profile.',
            referenceType: 'verification',
            referenceId: null,
        );
    }

    /** @return int how many workers were notified */
    public function jobMatched(JobPost $job): int
    {
        $job->loadMissing(['skills', 'psgcLocation']);
        $skillIds = $job->skills->pluck('id');

        $candidates = \App\Models\WorkerProfile::query()
            ->with(['skills', 'psgcLocation'])
            ->where('user_id', '!=', $job->employer_id)
            ->where(function ($q) use ($job, $skillIds) {
                $q->where('category_id', $job->category_id);

                if ($skillIds->isNotEmpty()) {
                    $q->orWhereHas('skills', fn ($s) => $s->whereIn('skills.id', $skillIds));
                }
            })
            ->get()
            ->filter(fn ($profile) => $profile->isSetupCompleted());

        $ranked = $candidates
            ->map(fn ($profile) => [
                'profile' => $profile,
                'score' => \App\Services\JobMatchService::score($job, $profile)['score'],
            ])
            ->filter(fn ($row) => $row['score'] >= self::MIN_NOTIFY_SCORE)
            ->sortByDesc('score')
            ->take(self::MAX_RECIPIENTS);

        $notified = 0;

        foreach ($ranked as $row) {
            $sent = $this->push(
                userId: $row['profile']->user_id,
                audience: UserNotification::AUDIENCE_WORKER,
                type: UserNotification::JOB_MATCH,
                title: 'New job for you',
                body: '"' . $job->title . '" in ' . ($job->location ?: 'your area')
                    . ' matches your skills.',
                referenceType: 'job',
                referenceId: $job->id,
                actorId: $job->employer_id,
            );

            if ($sent !== null) {
                $notified++;
            }
        }

        return $notified;
    }
}
