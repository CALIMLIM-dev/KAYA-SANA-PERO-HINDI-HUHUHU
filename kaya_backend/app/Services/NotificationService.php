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

        // Shared rows count towards BOTH badges, matching scopeForAudience.
        // Without this the bell disagrees with the list it opens.
        $shared = (int) $counts->get(UserNotification::AUDIENCE_BOTH, 0);

        $this->realtime->push(new NotificationPushed(
            notification: $notification,
            unreadWorker: (int) $counts->get(UserNotification::AUDIENCE_WORKER, 0) + $shared,
            unreadEmployer: (int) $counts->get(UserNotification::AUDIENCE_EMPLOYER, 0) + $shared,
            // Every unread row counted once, which the two badges above cannot
            // give you by addition now that shared rows sit in both.
            unreadTotal: (int) $counts->sum(),
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

    /*
        A post is a week from expiring.

        Both sides, deliberately. The employer needs to know they are about to
        lose the post; the workers with an application on it need it more -
        theirs is about to be declined by a date they cannot see, in the middle
        of a conversation they may be having about it. The barya comes back
        either way, which makes it fair; the notice is what stops it being a
        shock.
    */
    public function jobExpiringSoon(JobPost $job, int $days, \Illuminate\Support\Collection $applicantIds): void
    {
        $when = $days === 1 ? 'tomorrow' : "in {$days} days";

        $this->push(
            userId: $job->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: 'job.expiring',
            title: 'Your job post ends ' . $when,
            body: '"' . $job->title . '" comes down ' . $when
                . '. Move the end date if you are still hiring.',
            referenceType: 'job',
            referenceId: $job->id,
        );

        foreach ($applicantIds as $workerId) {
            $this->push(
                userId: $workerId,
                audience: UserNotification::AUDIENCE_WORKER,
                type: 'job.expiring',
                title: 'A job you applied for expires ' . $when,
                body: 'If "' . $job->title . '" is not extended, your '
                    . 'application is withdrawn and the Barya is returned.',
                referenceType: 'job',
                referenceId: $job->id,
            );
        }
    }

    /*
        A post has expired and its applications went with it.

        The refund is named in the body because it is the first thing a worker
        will want to know, and being told after the fact that money came back
        is very different from noticing a balance changed.
    */
    public function jobExpired(JobPost $job, \Illuminate\Support\Collection $applicantIds): void
    {
        $this->push(
            userId: $job->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: 'job.expired',
            title: 'Your job post has ended',
            body: '"' . $job->title . '" reached its end date and is off '
                . 'the feed. Post it again if you are still hiring.',
            referenceType: 'job',
            referenceId: $job->id,
        );

        foreach ($applicantIds as $workerId) {
            $this->push(
                userId: $workerId,
                audience: UserNotification::AUDIENCE_WORKER,
                type: 'job.expired',
                title: 'A job you applied for has ended',
                body: '"' . $job->title . '" reached its end date before anyone '
                    . 'was hired. Your Barya has been returned.',
                referenceType: 'job',
                referenceId: $job->id,
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

        /*
            Not scoped to the role on the latest job.

            The inbox shows one thread per person and does not filter by mode,
            so scoping this would hide the alert for a conversation the
            recipient can plainly see -- and since the roles swap when two
            people hire each other, which mode hid it would change over time.
        */
        $this->push(
            userId: $recipientId,
            audience: UserNotification::AUDIENCE_BOTH,
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

        The same judgement the employer's lists make, pointed the other way:
        JobMatchService decides, and only its top tier is told - a worker who
        holds a skill the job asks for, or, for a job naming no skills, works
        in its trade. A trade alone is enough to appear in a list, never
        enough to make a phone buzz.

        It used to narrow the field in SQL first, to workers whose setup
        category was the job's exact category or who held one of its exact
        skill ids. Anyone who had typed their skill, or whose setup trade was
        filed somewhere else, was never even scored - so the matcher's
        understanding of abbreviations, shared words and confirmed synonyms
        never reached a notification. Every finished profile is scored now.

        Limits, because a notification is far more intrusive than a row:
        nobody further than the distance they could apply from, nobody told
        about the same job twice, at most DAILY_CAP a day per worker, and at
        most MAX_RECIPIENTS per job.
    */
    public const DAILY_CAP = 3;
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
    /*
        A past worker is available again.

        Reference is the worker, not a job: there is no job yet, and the
        point of the notification is the person. Tapping it opens their
        profile, where the employer can invite them.
    */
    public function workAgainRequested(\App\Models\User $worker, int $employerId): void
    {
        $this->push(
            userId: $employerId,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: UserNotification::WORK_AGAIN_REQUESTED,
            title: 'Available for work again',
            body: ($worker->name ?? 'A worker')
                . ' worked with you before and is looking for work again.',
            referenceType: 'user',
            referenceId: $worker->id,
            actorId: $worker->id,
        );
    }

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

    /** KAYA took a post down. The employer hears why; applicants hear their Barya is back. */
    public function jobClosedByAdmin(JobPost $job, string $reason, \Illuminate\Support\Collection $applicantIds): void
    {
        $this->push(
            userId: $job->employer_id,
            audience: UserNotification::AUDIENCE_EMPLOYER,
            type: 'job.closed',
            title: 'Your job post was closed by KAYA',
            body: '"' . $job->title . '" was taken down. Reason: ' . $reason,
            referenceType: 'job',
            referenceId: $job->id,
        );

        foreach ($applicantIds as $workerId) {
            $this->push(
                userId: $workerId,
                audience: UserNotification::AUDIENCE_WORKER,
                type: 'job.closed',
                title: 'A job you applied for was closed',
                body: '"' . $job->title . '" was taken down by KAYA. Your Barya has been returned.',
                referenceType: 'job',
                referenceId: $job->id,
            );
        }
    }

    /** The board read the post and let it up. */
    public function communityPostApproved(\App\Models\CommunityPost $post): void
    {
        $this->push(
            userId: $post->user_id,
            audience: $this->communityAudience($post),
            type: 'community.approved',
            title: 'Your community post is up',
            body: '"' . $post->title . '" is on the board now.',
            referenceType: 'community_post',
            referenceId: $post->id,
        );
    }

    /** Read and refused, before it ever went up. The barya went back. */
    public function communityPostRejected(\App\Models\CommunityPost $post, string $reason): void
    {
        $this->push(
            userId: $post->user_id,
            audience: $this->communityAudience($post),
            type: 'community.rejected',
            title: 'Your community post was not approved',
            body: '"' . $post->title . '" did not go up. Reason: ' . $reason
                . '. Your Barya has been returned.',
        );
    }

    /** Somebody answered under a notice. Only the poster is told. */
    public function communityPostAnswered(\App\Models\CommunityPost $post, \App\Models\User $who): void
    {
        $this->push(
            userId: $post->user_id,
            audience: $this->communityAudience($post),
            type: 'community.comment',
            title: 'New comment on your post',
            body: $who->name . ' commented on "' . $post->title . '".',
            referenceType: 'community_post',
            referenceId: $post->id,
            actorId: $who->id,
        );
    }

    /*
        Which half of a hybrid account a community notification belongs to.

        A business advert is employer business and a worker advert is worker
        business, so the badge lands on the side of the account that wrote it
        rather than on whichever one happens to be open.
    */
    private function communityAudience(\App\Models\CommunityPost $post): string
    {
        return $post->type === \App\Models\CommunityPost::TYPE_BUSINESS
            ? UserNotification::AUDIENCE_EMPLOYER
            : UserNotification::AUDIENCE_WORKER;
    }

    /** KAYA answered somebody who wrote to support. */
    public function supportReplied(\App\Models\User $user): void
    {
        $this->push(
            userId: $user->id,
            audience: UserNotification::AUDIENCE_BOTH,
            type: 'support.replied',
            title: 'KAYA replied',
            body: 'There is an answer waiting in Help and support.',
        );
    }

    /*
        A badge was earned, and it paid.

        Worth telling somebody about for the same reason it is worth paying
        for: a badge that appears silently on a profile nobody has opened is
        indistinguishable from nothing happening.
    */
    public function badgeEarned(\App\Models\User $user, string $label, int $amount, string $side): void
    {
        $this->push(
            userId: $user->id,
            audience: $side === 'employer'
                ? UserNotification::AUDIENCE_EMPLOYER
                : UserNotification::AUDIENCE_WORKER,
            type: 'badge.earned',
            title: 'You earned the ' . $label . ' badge',
            body: 'It is on your profile now, and ' . $amount . ' Barya has been added to your wallet.',
        );
    }

    /*
        A report was upheld and the account was warned rather than suspended.

        The point of a warning is that the person hears it. Closing a report
        as handled and telling nobody leaves an account that has no idea it
        was reported, which is how the same thing happens again.

        Lands in the account category rather than under worker or employer:
        it is about the account, whichever side of it was complained about.
    */
    public function moderationWarning(\App\Models\User $user, ?string $note = null): void
    {
        $this->push(
            userId: $user->id,
            audience: UserNotification::AUDIENCE_BOTH,
            type: 'moderation.warning',
            title: 'A warning from KAYA',
            body: 'Somebody reported your account and we looked into it. '
                . ($note ?: 'Please keep to the community rules.')
                . ' Another report like this can lead to a suspension.',
        );
    }

    /*
        A report was filed about you, and you may answer it.

        Who filed it and what they wrote stay private. The reason and the
        chance to give your side do not: a decision made on one account of
        what happened is not a fair one.
    */
    public function reportFiled(\App\Models\Report $report): void
    {
        $this->push(
            userId: $report->reported_id,
            audience: UserNotification::AUDIENCE_BOTH,
            type: 'report.filed',
            title: 'A report about your account',
            body: 'Somebody reported your account for: ' . $report->reasonLabel()
                . '. Tap to tell our team your side before a decision is made.',
            referenceType: 'report',
            referenceId: $report->id,
        );
    }

    /*
        What came of a report, to the person who filed it.

        The reporter heard nothing once they had filed, so a report that was
        acted on looked exactly like one that was ignored. Told the outcome
        in a sentence - never what was done to the other account in detail.
    */
    public function reportDecided(\App\Models\Report $report): void
    {
        $upheld = $report->status === 'resolved';

        $this->push(
            userId: $report->reporter_id,
            audience: UserNotification::AUDIENCE_BOTH,
            type: 'report.decided',
            title: $upheld ? 'Your report was upheld' : 'Your report was reviewed',
            body: $upheld
                ? 'We looked into your report and took action. Thank you for telling us.'
                : 'We looked into your report and did not find a rule broken this time.',
        );

        // The reported person hears it was closed, unless a warning or a
        // suspension already told them.
        if ($report->status === 'dismissed' || str_starts_with((string) $report->resolution_note, 'No action taken')) {
            $this->push(
                userId: $report->reported_id,
                audience: UserNotification::AUDIENCE_BOTH,
                type: 'report.closed',
                title: 'A report about your account was closed',
                body: 'Our team reviewed it and no action was taken.',
            );
        }
    }
    /** An administrator took a community post down; the poster hears why. */
    public function communityPostRemoved(\App\Models\CommunityPost $post, string $reason): void
    {
        $this->push(
            userId: $post->user_id,
            audience: $post->type === \App\Models\CommunityPost::TYPE_BUSINESS
                ? UserNotification::AUDIENCE_EMPLOYER
                : UserNotification::AUDIENCE_WORKER,
            type: 'community.removed',
            title: 'Your community post was removed',
            body: '"' . $post->title . '" was taken down by KAYA. Reason: ' . $reason,
        );
    }

    /*
        An announcement from KAYA to everyone, or to one side of it.

        Goes through push() one person at a time so the per-user switches
        still apply and each row broadcasts. An announcement is account
        business, not job business, so it lands in the account category and
        is not silenced by someone muting job alerts.

        @return int how many people it reached
    */
    public function announcement(string $audience, string $title, string $body): int
    {
        $recipients = \App\Models\User::query()
            ->where('user_type', '!=', 'admin')
            ->where('is_suspended', false)
            ->when($audience === UserNotification::AUDIENCE_WORKER, fn ($q) => $q->whereHas('workerProfile'))
            ->when($audience === UserNotification::AUDIENCE_EMPLOYER, fn ($q) => $q->whereHas('employerProfile'))
            ->pluck('id');

        $sent = 0;

        foreach ($recipients as $userId) {
            $sent += $this->push(
                userId: $userId,
                audience: $audience,
                type: 'announcement.sent',
                title: $title,
                body: $body,
            ) ? 1 : 0;
        }

        return $sent;
    }

    /** @return int how many workers were notified */
    public function jobMatched(JobPost $job): int
    {
        if (! $job->isOpenForApplications()) {
            return 0;
        }

        $job->loadMissing(['skills', 'psgcLocation', 'category']);

        $candidates = \App\Models\WorkerProfile::query()
            ->with(['skills', 'psgcLocation', 'category', 'user:id,is_verified', 'licenses:id,user_id', 'certifications:id,user_id'])
            ->where('user_id', '!=', $job->employer_id)
            ->get()
            ->filter(fn ($profile) => $profile->isSetupCompleted());

        $ranked = $candidates
            ->map(fn ($profile) => $this->matchFor($job, $profile))
            ->filter()
            ->sortByDesc('rank')
            ->take(self::MAX_RECIPIENTS);

        $notified = 0;
        foreach ($ranked as $row) {
            $notified += $this->tellAboutJob($job, $row['profile']->user_id) ? 1 : 0;
        }

        return $notified;
    }

    /*
        The other direction: a worker whose skills changed.

        Fit was only ever judged when a job was posted, so a worker who added
        the skill an open job asks for heard nothing about it until some
        other job went up. Open jobs near them that they now meet, best fit
        first, within the same daily cap.
    */
    public function workerMatched(\App\Models\WorkerProfile $profile): int
    {
        if (! $profile->isSetupCompleted()) {
            return 0;
        }

        $profile->loadMissing(['skills', 'psgcLocation', 'category', 'user:id,is_verified', 'licenses:id,user_id', 'certifications:id,user_id']);

        $jobs = JobPost::query()
            ->with(['skills', 'psgcLocation', 'category'])
            ->where('status', JobPost::STATUS_OPEN)
            ->where('employer_id', '!=', $profile->user_id)
            ->get()
            ->filter(fn (JobPost $job) => $job->isOpenForApplications());

        $ranked = $jobs
            ->map(fn (JobPost $job) => ($m = $this->matchFor($job, $profile)) ? $m + ['job' => $job] : null)
            ->filter()
            ->sortByDesc('rank');

        $notified = 0;
        foreach ($ranked as $row) {
            if ($this->tellAboutJob($row['job'], $profile->user_id)) {
                $notified++;
            }
        }

        return $notified;
    }

    /**
     * The match, when it is worth a notification: the top tier, within
     * reach. Null otherwise.
     *
     * @return array{profile: \App\Models\WorkerProfile, rank: float}|null
     */
    private function matchFor(JobPost $job, \App\Models\WorkerProfile $profile): ?array
    {
        $match = \App\Services\JobMatchService::score($job, $profile);

        if ($match['tier'] !== \App\Services\JobMatchService::TIER_MEETS) {
            return null;
        }

        // Unknown distance does not block, the same as applying.
        $km = $match['distance_km'];
        if ($km !== null && $km > \App\Services\WorkingDistance::LIMIT_KM) {
            return null;
        }

        return [
            'profile' => $profile,
            'rank' => \App\Services\JobMatchService::rank(
                $match['tier'],
                $match['score'],
                \App\Services\JobMatchService::strength($profile),
            ),
        ];
    }

    /** Sends one job-match notification, unless it was sent before or today's cap is reached. */
    private function tellAboutJob(JobPost $job, int $userId): bool
    {
        $already = UserNotification::query()
            ->where('user_id', $userId)
            ->where('type', UserNotification::JOB_MATCH)
            ->where('reference_type', 'job')
            ->where('reference_id', $job->id)
            ->exists();

        if ($already) {
            return false;
        }

        $today = UserNotification::query()
            ->where('user_id', $userId)
            ->where('type', UserNotification::JOB_MATCH)
            ->where('created_at', '>=', now()->startOfDay())
            ->count();

        if ($today >= self::DAILY_CAP) {
            return false;
        }

        $asksForSkills = $job->relationLoaded('skills') && $job->skills->isNotEmpty();

        return $this->push(
            userId: $userId,
            audience: UserNotification::AUDIENCE_WORKER,
            type: UserNotification::JOB_MATCH,
            title: 'New job for you',
            body: '"' . $job->title . '" in ' . ($job->location ?: 'your area')
                . ($asksForSkills ? ' asks for skills you have.' : ' is in your line of work.'),
            referenceType: 'job',
            referenceId: $job->id,
            actorId: $job->employer_id,
        ) !== null;
    }
}
