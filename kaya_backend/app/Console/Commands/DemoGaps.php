<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * What real accounts have done that the sample accounts never have.
 *
 * For every table of things people do, counts rows owned by real accounts
 * and by sample accounts (email at the given domain), split by kind where
 * the table has one (status, type, subject, reason ...), and marks each kind
 * real people have and the demo lacks. Reads only; changes nothing.
 *
 *     php artisan kaya:demo-gaps sample.kaya.test
 */
class DemoGaps extends Command
{
    protected $signature = 'kaya:demo-gaps {domain : Email domain of the sample accounts} {--all : List every kind, not only the gaps}';

    protected $description = 'List what real users have done that the sample accounts never have';

    /** Who a row belongs to, first column found wins. */
    private const OWNER = ['user_id', 'reporter_id', 'reviewer_id', 'worker_id', 'employer_id', 'blocker_id', 'viewer_id', 'created_by', 'sender_id'];

    /** What a row is, first column found wins. */
    private const KIND = ['reported_type', 'subject_type', 'type', 'status', 'reason', 'category', 'method', 'action'];

    /** Activity tables worth comparing (system, cache and lookup tables are left out). */
    private const TABLES = [
        'applications', 'badge_rewards', 'boosts', 'bug_reports', 'categories', 'community_comments',
        'community_post_likes', 'community_posts', 'consents', 'conversations', 'credit_payments',
        'credit_transactions', 'credit_unlocks', 'invitations', 'job_tracking_sessions', 'jobs_posts',
        'messages', 'profile_views', 'reports', 'reviews', 'saved_jobs', 'schedule_proposals', 'strikes',
        'support_messages', 'support_threads', 'user_blocks', 'verifications', 'worker_certifications_new',
        'worker_experiences', 'worker_license_examinations', 'worker_licenses', 'worker_skills_new',
    ];

    public function handle(): int
    {
        $domain = ltrim((string) $this->argument('domain'), '@');
        $sample = DB::table('users')->where('email', 'like', "%@{$domain}")->pluck('id')->all();
        $real = DB::table('users')->where('email', 'not like', "%@{$domain}")
            ->where(fn ($q) => $q->whereNull('user_type')->orWhere('user_type', '!=', 'admin'))
            ->pluck('id')->all();

        $this->info(sprintf('Real accounts: %d   Sample accounts: %d', count($real), count($sample)));
        if ($sample === []) {
            $this->warn("No accounts at @{$domain}.");

            return self::FAILURE;
        }

        $rows = [];
        foreach (self::TABLES as $table) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            $columns = Schema::getColumnListing($table);
            $owner = collect(self::OWNER)->first(fn ($c) => in_array($c, $columns, true));
            if ($owner === null) {
                continue;
            }
            $kind = collect(self::KIND)->first(fn ($c) => in_array($c, $columns, true));

            $count = function (array $ids) use ($table, $owner, $kind) {
                $q = DB::table($table)->whereIn($owner, $ids);

                return $kind
                    ? $q->selectRaw("COALESCE({$kind}, '(none)') as k, COUNT(*) as n")->groupBy('k')->pluck('n', 'k')->all()
                    : ['(all)' => $q->count()];
            };

            $r = $this->inChunks($real, $count);
            $s = $this->inChunks($sample, $count);

            foreach (array_unique(array_merge(array_keys($r), array_keys($s))) as $k) {
                $realN = (int) ($r[$k] ?? 0);
                $sampleN = (int) ($s[$k] ?? 0);
                $gap = $realN > 0 && $sampleN === 0;
                if ($gap || $this->option('all')) {
                    $rows[] = [$table, $kind ? "{$kind} = {$k}" : 'all', $realN, $sampleN, $gap ? 'MISSING IN DEMO' : ''];
                }
            }
        }

        if ($rows === []) {
            $this->info('The sample accounts have every kind of activity real accounts have.');

            return self::SUCCESS;
        }

        $this->table(['Table', 'Kind', 'Real', 'Sample', ''], $rows);

        return self::SUCCESS;
    }

    /** Runs $count over $ids in chunks (a long IN list is refused by some databases) and adds up. */
    private function inChunks(array $ids, callable $count): array
    {
        $total = [];
        foreach (array_chunk($ids ?: [0], 500) as $chunk) {
            foreach ($count($chunk) as $k => $n) {
                $total[$k] = ($total[$k] ?? 0) + $n;
            }
        }

        return $total;
    }
}
