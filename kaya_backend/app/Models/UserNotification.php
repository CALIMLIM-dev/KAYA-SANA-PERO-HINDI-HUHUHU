<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserNotification extends Model
{
    protected $table = 'user_notifications';

    protected $fillable = [
        'user_id',
        'audience',
        'type',
        'title',
        'body',
        'reference_type',
        'reference_id',
        'read_at',
    ];

    protected $casts = [
        'read_at' => 'datetime',
    ];

    // Audiences — which side of the marketplace a notification speaks to.
    public const AUDIENCE_WORKER = 'worker';
    public const AUDIENCE_EMPLOYER = 'employer';

    /*
        For notifications whose target is shared between both roles.

        Only messages use this, and deliberately so. The inbox is not filtered
        by mode -- there is one thread per person regardless of who hired whom
        -- so a notification that opens a thread must not be hidden by a mode
        the thread itself ignores. Role-scoped news stays role-scoped.
    */
    public const AUDIENCE_BOTH = 'both';

    /**
     * Event types. Kept as constants so the app and the emitters agree on the
     * exact strings — the client switches on these for icons and routing.
     */
    public const APPLICATION_RECEIVED = 'application.received';
    public const APPLICATION_ACCEPTED = 'application.accepted';
    public const APPLICATION_REJECTED = 'application.rejected';
    public const INVITATION_RECEIVED  = 'invitation.received';
    public const INVITATION_ACCEPTED  = 'invitation.accepted';
    public const INVITATION_DECLINED  = 'invitation.declined';
    public const MESSAGE_RECEIVED     = 'message.received';
    public const JOB_COMPLETED        = 'job.completed';
    /*
        A new job that suits this worker.

        Under the 'job.' prefix deliberately, so categoryFor() files it with the
        other job notifications and the existing "jobs" switch in settings mutes
        it. A new notification type that no preference covers is one users
        cannot turn off.
    */
    public const JOB_MATCH            = 'job.match';

    /*
        The events a person is waiting on, which were silent.

        Each of these is a moment where the other party has done something the
        first party has to respond to, or would simply want to know. Without a
        notification the only way to find out is to reopen the app and check —
        which is what "the app feels dead" actually means.
    */

    /** One side confirmed the work is done; the other still has to. */
    public const APPLICATION_COMPLETION_PENDING = 'application.completion_pending';

    /** An applicant pulled out, so the employer's shortlist just changed. */
    public const APPLICATION_WITHDRAWN = 'application.withdrawn';

    /** Somebody reviewed you. */
    public const REVIEW_RECEIVED = 'review.received';

    /** The job is finished and a review can now be written. */
    public const REVIEW_REQUESTED = 'review.requested';

    /** An admin approved or rejected an identity submission. */
    public const VERIFICATION_APPROVED = 'verification.approved';
    public const VERIFICATION_REJECTED = 'verification.rejected';

    /**
     * Which settings switch governs each type.
     *
     * Derived from the prefix rather than listed one by one, so a new
     * `application.*` type is covered the day it is added instead of silently
     * ignoring the user's preference.
     */
    public static function categoryFor(string $type): string
    {
        return [
            'application'  => 'applications',
            'invitation'   => 'invitations',
            'message'      => 'messages',
            'job'          => 'jobs',
            'review'       => 'reviews',
            // Identity checks are account business, not job business — someone
            // who mutes job alerts still needs to hear that their ID was
            // rejected and their verified badge is not coming.
            'verification' => 'account',
        ][explode('.', $type)[0]] ?? 'jobs';
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function isRead(): bool
    {
        return $this->read_at !== null;
    }

    /**
     * The wire shape, defined once.
     *
     * A notification reaches the app two ways — fetched over REST and pushed
     * over the socket — and the client cannot afford for those to differ. If
     * the pushed row were missing a field the fetched row has, a live-arriving
     * notification would render differently from the same row after a refresh.
     */
    public function toPayload(): array
    {
        return [
            'id'             => $this->id,
            'type'           => $this->type,
            'audience'       => $this->audience,
            'title'          => $this->title,
            'body'           => $this->body,
            'reference_type' => $this->reference_type,
            'reference_id'   => $this->reference_id,
            'is_read'        => $this->isRead(),
            'read_at'        => $this->read_at?->toIso8601String(),
            'created_at'     => $this->created_at?->toIso8601String(),
            'age'            => $this->created_at?->diffForHumans(),
        ];
    }

    public function scopeUnread($query)
    {
        return $query->whereNull('read_at');
    }

    public function scopeForAudience($query, ?string $audience)
    {
        // No audience means "everything", which is what a neutral account and
        // an unfocused hybrid should see.
        if ($audience === null) {
            return $query;
        }

        // AUDIENCE_BOTH survives every filter, which is the whole point of it.
        return $query->where(
            fn ($q) => $q->where('audience', $audience)
                ->orWhere('audience', self::AUDIENCE_BOTH)
        );
    }
}
