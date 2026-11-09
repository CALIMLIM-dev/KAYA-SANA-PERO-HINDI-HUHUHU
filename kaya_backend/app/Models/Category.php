<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    protected $fillable = ['name', 'icon', 'is_active', 'is_custom', 'created_by', 'maps_to_id', 'removed_at'];

    protected $casts = [
        'is_active'  => 'boolean',
        'is_custom'  => 'boolean',
        'removed_at' => 'datetime',
    ];

    /*
        What a person can pick: the catalogue, and their own custom
        categories. Somebody else's custom category is theirs alone.
    */
    public function scopePickableBy($query, ?User $user)
    {
        return $query->where('is_active', true)
            ->whereNull('removed_at')
            ->where(fn ($q) => $q->where('is_custom', false)
                ->when($user, fn ($q2) => $q2->orWhere('created_by', $user->id)));
    }

    /** The catalogue trade a custom category means, when it is known. */
    public function mapsTo()
    {
        return $this->belongsTo(Category::class, 'maps_to_id');
    }

    /*
        Whether its creator can take it off their list: not while an open
        post or anybody's profile still files work under it. Closed posts do
        not count; they keep showing the name.
    */
    public function removableByOwner(): bool
    {
        return ! $this->jobs()->whereIn('status', ['open', 'in_progress'])->exists()
            && ! WorkerProfile::where('category_id', $this->id)->exists();
    }

    public function jobs()
    {
        return $this->hasMany(JobPost::class);
    }

    public function skills()
    {
        return $this->hasMany(Skill::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /*
        Whether deleting it outright would take something with it.

        The database cascades: a deleted category takes every worker skill
        filed under it, and its skills take every post's and worker's use of
        them. So it is deleted outright only when nothing uses it; otherwise
        what is under it is moved somewhere first.
    */
    public function isInUse(): bool
    {
        $skillIds = $this->skills()->pluck('id');

        return $this->jobs()->exists()
            || WorkerProfile::where('category_id', $this->id)->exists()
            || WorkerSkill::where('category_id', $this->id)->orWhereIn('skill_id', $skillIds)->exists()
            || \Illuminate\Support\Facades\DB::table('job_skills')->whereIn('skill_id', $skillIds)->exists();
    }
}
