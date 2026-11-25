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
        Why its creator cannot take it off their list, or null when they can.

        Not while an open post files work under it. Closed posts do not
        count; they keep showing the name. Their own profile does not hold it
        either - nothing in the app changes a main category, so that was a
        refusal with no way round it. Their skills under it stay as the words
        they typed, and the profile takes the category of the rest.
    */
    public function removeForOwner(User $owner): ?string
    {
        if ($this->jobs()->whereIn('status', ['open', 'in_progress'])->exists()) {
            return 'An open job post still uses this category. Close it first.';
        }

        if (WorkerProfile::where('category_id', $this->id)->where('user_id', '!=', $owner->id)->exists()) {
            return 'Another profile still uses this category.';
        }

        try {
            \Illuminate\Support\Facades\DB::transaction(function () use ($owner) {
                $this->forceFill(['removed_at' => now()])->save();

                $mine = WorkerProfile::where('user_id', $owner->id)->where('category_id', $this->id);
                if ($mine->exists()) {
                    $mine->update(['category_id' => null]);
                    WorkerProfile::fillCategories([$owner->id]);

                    if (WorkerProfile::where('user_id', $owner->id)->whereNull('category_id')->exists()) {
                        throw new \DomainException('This is your only category. Add a skill under another one first, then remove this.');
                    }
                }

                WorkerSkill::where('user_id', $owner->id)->where('category_id', $this->id)->update(['category_id' => null]);
                WorkerSkill::where('user_id', $owner->id)->whereIn('skill_id', $this->skills()->pluck('id'))->update(['skill_id' => null]);
            });
        } catch (\DomainException $only) {
            // Undone with the transaction: the category is still theirs.
            $this->refresh();

            return $only->getMessage();
        }

        return null;
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

    /**
     * Who deleting it would touch, for the administrator to read first.
     *
     * @return array{jobs: int, workers: int, left: int}  left: workers whose only category this is
     */
    public function deletionImpact(): array
    {
        $workers = WorkerSkill::where('category_id', $this->id)
            ->orWhereIn('skill_id', $this->skills()->pluck('id'))
            ->pluck('user_id')
            ->merge(WorkerProfile::where('category_id', $this->id)->pluck('user_id'))
            ->unique();

        $others = WorkerProfile::whereIn('user_id', $workers)
            ->whereNotNull('category_id')->where('category_id', '!=', $this->id)
            ->pluck('user_id')
            ->merge(WorkerSkill::with('skill:id,category_id')->whereIn('user_id', $workers)->get()
                ->filter(fn (WorkerSkill $s) => array_diff(
                    array_filter([$s->category_id, $s->skill?->category_id]),
                    [$this->id],
                ) !== [])
                ->pluck('user_id'));

        return [
            'jobs'    => $this->jobs()->count(),
            'workers' => $workers->count(),
            'left'    => $workers->diff($others)->count(),
        ];
    }
}
