<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Dual review — the half that was never built.

    Reviews went both ways already: a worker could review an employer and the
    row was stored. It was then displayed nowhere and counted for nothing,
    because employer_profiles has no rating columns at all. Only
    worker_profiles.rating_avg was ever updated, so one direction of a
    supposedly mutual system was write-only.

    The second problem is specific to this app's hybrid accounts. A review
    carried no record of which side it was about, and the aggregate was applied
    to whatever profile the reviewee happened to have. For someone who is both a
    worker and an employer — which is the whole point of the hybrid model, and
    two of the demo accounts — reviews earned as an employer landed on their
    worker rating. Their two reputations were one number.

    reviewee_role fixes that: a rating counts towards the reputation of the role
    the person was actually playing on that job.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('reviews') && ! Schema::hasColumn('reviews', 'reviewee_role')) {
            Schema::table('reviews', function (Blueprint $table) {
                // Plain string rather than an enum: widening a MySQL enum needs
                // a raw ALTER that sqlite cannot run, which has already cost
                // this project one divergence between test and production
                // schemas (applications.status).
                $table->string('reviewee_role', 10)->nullable()->after('reviewee_id');
                $table->index(['reviewee_id', 'reviewee_role'], 'reviews_reviewee_role_index');
            });

            /*
                Backfill from the job: the reviewee is the employer if they
                posted it, otherwise they were the hired worker.

                Done in SQL rather than in PHP so it does not depend on models
                that may change later — a migration has to keep working against
                the schema as it was, not as the code becomes.
            */
            DB::table('reviews')->whereNull('reviewee_role')->update([
                'reviewee_role' => DB::raw(
                    "CASE WHEN reviewee_id = (SELECT employer_id FROM jobs_posts WHERE jobs_posts.id = reviews.job_id)
                          THEN 'employer' ELSE 'worker' END"
                ),
            ]);
        }

        /*
            One review per reviewer per person per job.

            The controller checked this with a read followed by a write, which
            two taps on a slow connection can both pass. Reviewer AND reviewee
            are both in the key on purpose: an employer who hires two people for
            one job legitimately reviews two people on that job.
        */
        if (Schema::hasTable('reviews') && ! $this->hasIndex('reviews', 'reviews_reviewer_reviewee_job_unique')) {
            $this->dedupe();

            Schema::table('reviews', function (Blueprint $table) {
                $table->unique(
                    ['reviewer_id', 'reviewee_id', 'job_id'],
                    'reviews_reviewer_reviewee_job_unique'
                );
            });
        }

        if (Schema::hasTable('employer_profiles') && ! Schema::hasColumn('employer_profiles', 'rating_avg')) {
            Schema::table('employer_profiles', function (Blueprint $table) {
                // Mirrors worker_profiles exactly, so the two sides of a hire
                // are described the same way and neither reads as an
                // afterthought.
                $table->decimal('rating_avg', 3, 2)->default(0)->after('setup_completed');
                $table->unsignedInteger('rating_count')->default(0)->after('rating_avg');
            });
        }
    }

    /**
     * Existing duplicates would block the unique index. Keep the earliest —
     * it is the one the reviewer meant; anything after it is a double tap.
     */
    private function dedupe(): void
    {
        $groups = DB::table('reviews')
            ->select('reviewer_id', 'reviewee_id', 'job_id', DB::raw('MIN(id) as keep_id'))
            ->groupBy('reviewer_id', 'reviewee_id', 'job_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($groups as $group) {
            DB::table('reviews')
                ->where('reviewer_id', $group->reviewer_id)
                ->where('reviewee_id', $group->reviewee_id)
                ->where('job_id', $group->job_id)
                ->where('id', '!=', $group->keep_id)
                ->delete();
        }
    }

    private function hasIndex(string $table, string $index): bool
    {
        try {
            return collect(Schema::getIndexes($table))
                ->contains(fn ($i) => ($i['name'] ?? null) === $index);
        } catch (\Throwable) {
            return false;
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('reviews')) {
            Schema::table('reviews', function (Blueprint $table) {
                $table->dropUnique('reviews_reviewer_reviewee_job_unique');
                $table->dropIndex('reviews_reviewee_role_index');
                $table->dropColumn('reviewee_role');
            });
        }

        if (Schema::hasTable('employer_profiles')) {
            Schema::table('employer_profiles', function (Blueprint $table) {
                $table->dropColumn(['rating_avg', 'rating_count']);
            });
        }
    }
};
