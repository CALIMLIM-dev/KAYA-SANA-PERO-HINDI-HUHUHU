<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A notice the team posted for a problem many people have at once. */
class KnownIssue extends Model
{
    protected $fillable = ['topic', 'text', 'active', 'created_by'];

    protected $casts = ['active' => 'boolean'];

    public function createdBy()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** The newest notice for this topic, or for every topic. */
    public static function forTopic(string $topic): ?string
    {
        return static::where('active', true)
            ->where(fn ($q) => $q->where('topic', $topic)->orWhereNull('topic'))
            ->latest('id')
            ->value('text');
    }
}
