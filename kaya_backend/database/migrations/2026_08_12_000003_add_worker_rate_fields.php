<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * What a worker charges.
 *
 * Jobs have carried `budget_min` / `budget_max` / `budget_period` since the
 * start, but the worker side had nothing — a worker could not state a rate, an
 * employer browsing workers saw no pay at all, and filtering workers by rate
 * was impossible because there was no column to filter on.
 *
 * Nullable throughout: an existing worker has no rate on file, and forcing one
 * retroactively would either invent a number or lock people out of their own
 * profile. `rate_min` alone is a fixed rate; both set is a range.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->decimal('rate_min', 10, 2)->nullable()->after('bio');
            $table->decimal('rate_max', 10, 2)->nullable()->after('rate_min');

            // Matches jobs_posts.budget_period so a worker's rate and a job's
            // budget can be compared without translating units.
            $table->enum('rate_unit', ['hour', 'day', 'project'])
                ->default('day')->after('rate_max');

            /*
                Shown as "Open to offers", never as the word "negotiable".

                In Philippine online selling "negotiable" has come to mean "I
                priced this at random", and it is usually written *instead of* a
                number — which is exactly what breaks a salary filter. This flag
                sits beside a real rate, never in place of one.
            */
            $table->boolean('is_rate_negotiable')->default(false)->after('rate_unit');

            // Browsing workers filters on this constantly.
            $table->index(['rate_min', 'rate_max']);
        });
    }

    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropIndex(['rate_min', 'rate_max']);
            $table->dropColumn(['rate_min', 'rate_max', 'rate_unit', 'is_rate_negotiable']);
        });
    }
};
