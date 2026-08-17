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
            'application' => 'applications',
            'invitation'  => 'invitations',
            'message'     => 'messages',
            'job'         => 'jobs',
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

        return $query->where('audience', $audience);
    }
}
