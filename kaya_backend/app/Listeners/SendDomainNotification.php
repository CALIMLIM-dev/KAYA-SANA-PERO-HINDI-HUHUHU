<?php

namespace App\Listeners;

use App\Events\ApplicationAccepted;
use App\Events\ApplicationRejected;
use App\Events\ApplicationSubmitted;
use App\Events\InvitationAccepted;
use App\Events\InvitationDeclined;
use App\Events\InvitationSent;
use App\Events\JobCompleted;
use App\Events\MessageSent;
use App\Services\NotificationService;

/**
 * Turns domain events into notifications.
 *
 * One listener with a method per event rather than eight near-identical
 * classes. Registered explicitly in AppServiceProvider — Laravel's listener
 * auto-discovery matches on a `handle()` type-hint, which a multi-event
 * listener like this one cannot express.
 *
 * Controllers dispatch the event and move on; nothing about notifications
 * leaks into the hire/invite/message flows themselves, so a failure here can
 * never break the action that triggered it.
 */
class SendDomainNotification
{
    public function __construct(private NotificationService $notifications) {}

    public function onApplicationSubmitted(ApplicationSubmitted $event): void
    {
        $this->notifications->applicationReceived($event->application);
    }

    public function onApplicationAccepted(ApplicationAccepted $event): void
    {
        $this->notifications->applicationAccepted($event->application);
    }

    public function onApplicationRejected(ApplicationRejected $event): void
    {
        $this->notifications->applicationRejected($event->application);
    }

    public function onInvitationSent(InvitationSent $event): void
    {
        $this->notifications->invitationReceived($event->invitation);
    }

    public function onInvitationAccepted(InvitationAccepted $event): void
    {
        $this->notifications->invitationAccepted($event->invitation);
    }

    public function onInvitationDeclined(InvitationDeclined $event): void
    {
        $this->notifications->invitationDeclined($event->invitation);
    }

    public function onMessageSent(MessageSent $event): void
    {
        $this->notifications->messageReceived($event->message);
    }

    public function onJobCompleted(JobCompleted $event): void
    {
        $this->notifications->jobCompleted($event->job);

        /*
            A finished job is the commonest way a badge is earned, on both
            sides at once: the worker's first job and the employer's first
            hire are the same event seen from two ends.

            Settled here rather than on a read of the profile, so the Barya
            arrives when the thing happened instead of the next time somebody
            opens a screen. Paying twice is impossible whatever calls this -
            see BadgeRewardService.
        */
        $rewards = app(\App\Services\BadgeRewardService::class);

        if ($event->job->employer) {
            $rewards->settle($event->job->employer);
        }

        \App\Models\Application::where('job_id', $event->job->id)
            ->where('status', 'completed')
            ->with('worker')
            ->get()
            ->each(fn ($hire) => $hire->worker && $rewards->settle($hire->worker));
    }
}
