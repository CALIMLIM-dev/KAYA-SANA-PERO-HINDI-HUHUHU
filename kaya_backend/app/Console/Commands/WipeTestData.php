<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Empties everything the testers made, and nothing else.

    Months of trying things out leave a database that demos badly: half-made
    accounts with no name, jobs priced under rules that have since changed,
    conversations about work nobody did. This clears the people and the things
    they did, so what is left is the app rather than its history.

    Deliberately NOT migrate:fresh. That would drop `locations` too, and
    locations is the PSGC import - every region, province, city, municipality
    and barangay in the country. Rebuilding it needs the dataset, the import
    commands and the geocoding pass, and it has been a day's work before.

    So: the transactional tables are emptied, the reference tables are left
    alone, and administrators keep their accounts - whoever runs this has to
    be able to sign in afterwards.

    Irreversible. It asks first, it will not run without --force in a
    non-interactive shell, and --dry-run prints the counts and changes
    nothing.
*/
class WipeTestData extends Command
{
    protected $signature = 'kaya:wipe-test-data
                            {--dry-run : Count what would go and change nothing}
                            {--force : Skip the confirmation}';

    protected $description = 'Empty every account and everything they did, keeping locations, categories, skills and admins';

    /*
        Emptied, in an order that does not matter because the foreign keys are
        switched off around the loop - but listed children first anyway, so the
        printed report reads from the leaves up.
    */
    private const WIPE = [
        // What people did to each other
        'messages',
        'conversations',
        'schedule_proposals',
        'reviews',
        'reports',
        'invitations',
        'applications',
        'profile_views',
        'credit_unlocks',
        // Jobs and the board
        'saved_jobs',
        'job_location_pings',
        'job_tracking_sessions',
        'job_skills',
        'jobs_posts',
        'community_comments',
        'community_posts',
        // Money
        'credit_transactions',
        'credit_payments',
        'credit_wallets',
        'credit_webhook_events',
        'boosts',
        'badge_rewards',
        // Profiles and their parts
        'worker_skills',
        // The tables their current versions replaced. Still present, and
        // a wipe that left rows in them would be a wipe in name only.
        'worker_skills_new',
        'certifications',
        'experiences',
        'worker_certifications_new',
        'worker_licenses',
        'worker_license_examinations',
        'worker_experiences',
        'worker_profiles',
        'employer_profiles',
        // Accounts and everything hanging off one
        'verifications',
        'user_notifications',
        'support_messages',
        'support_threads',
        'admin_actions',
        'admin_notifications',
        'password_reset_tokens',
        'personal_access_tokens',
        'sessions',
    ];

    /*
        Left alone, and why.

        locations  the PSGC import, described above
        categories the trades, with jobs and profiles filed under them
        skills     the same
        credit_packages the price list
        users      emptied of everybody except administrators, below
    */
    /*
        system_settings is in here on purpose: it holds the prices an
        administrator has edited from the panel, and Pricing reads it to
        override the config at boot. Emptying it would quietly reset every
        price to whatever is compiled in.
    */
    private const KEEP = [
        'locations',
        'categories',
        'skills',
        'credit_packages',
        'system_settings',
    ];

    public function handle(): int
    {
        $dry = (bool) $this->option('dry-run');

        $admins = User::where('user_type', 'admin')->count();
        $people = User::where('user_type', '!=', 'admin')->count();

        $this->newLine();
        $this->line('Keeping: ' . implode(', ', self::KEEP) . ", and {$admins} administrator account(s).");
        $this->newLine();

        $total = 0;

        foreach (self::WIPE as $table) {
            if (! Schema::hasTable($table)) {
                $this->line("  skip   {$table} (no such table)");
                continue;
            }

            $count = DB::table($table)->count();
            $total += $count;

            $this->line(($dry ? '  would empty ' : '  empty  ') . "{$table} ({$count})");
        }

        $this->line(($dry ? '  would remove ' : '  remove ') . "{$people} non-admin account(s)");
        $total += $people;

        $this->newLine();

        if ($dry) {
            $this->info("Dry run. {$total} row(s) would go. Nothing was changed.");

            return self::SUCCESS;
        }

        if (! $this->option('force')
            && ! $this->confirm("This deletes {$total} rows and cannot be undone. Continue?")) {
            $this->warn('Nothing was changed.');

            return self::SUCCESS;
        }

        /*
            Foreign keys off for the duration.

            Truncate refuses on a table another one references, and the order
            that would satisfy every constraint is not worth working out for
            something that empties all of them anyway.
        */
        Schema::disableForeignKeyConstraints();

        try {
            foreach (self::WIPE as $table) {
                if (Schema::hasTable($table)) {
                    DB::table($table)->truncate();
                }
            }

            // Not truncate: the administrators stay, so this is a delete.
            User::where('user_type', '!=', 'admin')->delete();
        } finally {
            Schema::enableForeignKeyConstraints();
        }

        $this->newLine();
        $this->info("Done. {$total} row(s) removed.");
        $this->line('Administrators kept. Locations, categories, skills and packages untouched.');

        return self::SUCCESS;
    }
}
