<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Wipes every account and everything they created, back to a clean slate.
 *
 * For testing: the accounts and jobs made by hand during trials pile up, and
 * demo:clear only removes the seeded demo domain, not real signups. This clears
 * the lot.
 *
 * What survives, on purpose:
 *   - admin accounts (user_type = 'admin'), or the admin panel and the API's
 *     own auth would be gone and there would be no way back in
 *   - the reference tables nothing "owns": categories, skills, locations and
 *     credit packages. These are the app's vocabulary, not user data, and
 *     rebuilding them is a separate seeding job
 *
 * Everything else — profiles, jobs, applications, messages, reviews, credits,
 * verifications, tracking, notifications — is deleted. The tables are listed
 * explicitly rather than discovered, so what this touches is exactly what you
 * can read here, and FK checks are dropped for the duration so the order does
 * not matter.
 */
class ResetTestData extends Command
{
    protected $signature = 'test:reset {--force : Skip the confirmation prompt}';

    protected $description = 'Delete all non-admin accounts and everything they created (keeps admin and reference data)';

    /**
     * Every table holding user-created data.
     *
     * Cleared in full. Reference tables (categories, skills, locations,
     * credit_packages) and users are handled separately below, so they are
     * deliberately absent from this list.
     */
    private const WIPE = [
        'applications',
        'job_skills',
        'saved_jobs',
        'jobs_posts',
        'messages',
        'conversations',
        'job_tracking_sessions',
        'reviews',
        'invitations',
        'profile_views',
        'user_notifications',
        'verifications',
        'credit_transactions',
        'credit_payments',
        'credit_unlocks',
        'credit_webhook_events',
        'credit_wallets',
        'worker_skills',
        'worker_skills_new',
        'worker_experiences',
        'worker_certifications_new',
        'worker_licenses',
        'worker_license_examinations',
        'worker_profiles',
        'employer_profiles',
    ];

    public function handle(): int
    {
        $admins = User::where('user_type', 'admin')->count();
        if ($admins === 0) {
            $this->error('No admin account found. Refusing to run — this would leave you locked out.');
            return self::FAILURE;
        }

        $doomed = User::where('user_type', '!=', 'admin')->count();

        $this->line("Keeping {$admins} admin account(s) and the reference tables.");
        $this->line("Deleting {$doomed} account(s) and all of their jobs, messages, credits and the rest.");

        if (! $this->option('force')
            && ! $this->confirm('This cannot be undone. Continue?')) {
            $this->info('Nothing deleted.');
            return self::SUCCESS;
        }

        DB::transaction(function () {
            // Dropping FK checks means the table order below does not have to be
            // a correct topological sort — one less thing to get wrong. Only for
            // the length of this transaction.
            Schema::disableForeignKeyConstraints();

            foreach (self::WIPE as $table) {
                if (Schema::hasTable($table)) {
                    DB::table($table)->delete();
                }
            }

            // The accounts themselves, admins excepted. Their sessions and reset
            // tokens go too, so a deleted account cannot ride an old cookie back.
            $adminIds = User::where('user_type', 'admin')->pluck('id');
            foreach (['sessions', 'password_reset_tokens'] as $t) {
                if (Schema::hasTable($t) && Schema::hasColumn($t, 'user_id')) {
                    DB::table($t)->whereNotIn('user_id', $adminIds)->delete();
                }
            }
            User::whereNotIn('id', $adminIds)->delete();

            Schema::enableForeignKeyConstraints();
        });

        $this->info('Done. Every non-admin account and all their data is gone; admin and reference data kept.');

        return self::SUCCESS;
    }
}
