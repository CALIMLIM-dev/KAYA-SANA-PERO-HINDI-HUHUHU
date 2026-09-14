<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class Review extends Model
{
    protected $fillable = ['reviewer_id', 'reviewee_id', 'job_id', 'reviewee_role', 'rating', 'comment', 'tags'];

    protected $casts = [
        // Comes back as a list of strings rather than a json blob the client
        // would have to decode itself.
        'tags' => 'array',
        'hidden_at' => 'datetime',
    ];

    /*
        A hidden review is invisible everywhere by default.

        A global scope rather than a where clause in each of the seven places
        reviews are read, because the eighth place would forget it. The admin
        panel and the duplicate check ask for withHidden() explicitly.
    */
    protected static function booted(): void
    {
        static::addGlobalScope('visible', fn (Builder $q) => $q->whereNull('reviews.hidden_at'));
    }

    public static function withHidden(): Builder
    {
        return static::withoutGlobalScope('visible');
    }

    public function isHidden(): bool
    {
        return $this->hidden_at !== null;
    }

    public function reviewer() { return $this->belongsTo(User::class, 'reviewer_id'); }
    public function reviewee() { return $this->belongsTo(User::class, 'reviewee_id'); }
    public function job()      { return $this->belongsTo(JobPost::class, 'job_id'); }
    public function hider()    { return $this->belongsTo(User::class, 'hidden_by'); }
}
