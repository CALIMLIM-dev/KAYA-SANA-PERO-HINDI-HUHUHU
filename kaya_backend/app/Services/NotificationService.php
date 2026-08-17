<?php

namespace App\Services;

use App\Events\Realtime\NotificationPushed;
use App\Models\Application;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\Message;
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
                . ' applied to "' . $job->title . '"',
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
            body: 'Your application for "' . $job->title . '" was accepted',
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
            body: 'You were not selected for "' . $job->title . '"',
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
                . ' invited you to "' . $job->title . '"',
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
                . ' accepted your invitation to "' . $job->title . '"',
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
                . ' declined your invitation to "' . $job->title . '"',
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
}
