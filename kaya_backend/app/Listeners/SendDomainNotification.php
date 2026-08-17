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
    }
}
