<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Skill extends Model
{
    protected $fillable = ['name', 'category_id'];


    /*
        A name nobody has used before gets its vector now, not tonight.

        Here rather than at the call sites, because there are several
        and a new one would forget - the same reason CommunityPost
        archives through an event instead of at each caller.

        Nothing here can fail loudly. Embeddings swallows a timeout, a
        bad key and a provider outage and returns null, and a term that
        already has a vector costs one indexed read. With no key
        configured it returns before doing anything at all, which is
        also what makes this free in tests.

        A miss is not a problem: kaya:embed-skills picks it up, and
        matching falls back to SkillMatcher's string layers meanwhile.
    */
    protected static function booted(): void
    {
        static::created(function (self $row) {
            $term = (string) $row->name;

            if (trim($term) === '') {
                return;
            }

            try {
                app(\App\Services\Embeddings::class)->vectorFor($term);
            } catch (\Throwable $e) {
                // Saving the skill is the job. The vector is an extra.
                \Illuminate\Support\Facades\Log::info(
                    '[embeddings] on-save failed for "'.$term.'": '.$e->getMessage(),
                );
            }
        });
    }

    public function category() { return $this->belongsTo(Category::class); }
    public function workers() { return $this->belongsToMany(WorkerProfile::class, 'worker_skills'); }
    public function jobs()    { return $this->belongsToMany(JobPost::class, 'job_skills'); }
}
