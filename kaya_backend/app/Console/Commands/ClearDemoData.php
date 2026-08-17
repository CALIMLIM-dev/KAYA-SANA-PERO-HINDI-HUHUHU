<?php

namespace App\Console\Commands;

use App\Models\User;
use Database\Seeders\DemoDataSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Removes everything DemoDataSeeder created.
 *
 * Demo accounts are identified by their email domain, which is the only thing
 * that reliably separates them from real ones. Their jobs, applications,
 * profiles and verifications all cascade from the user row.
 *
 * Deliberately refuses to run in production. Seeded demo rows and real rows are
 * indistinguishable to a delete once they are mixed together, and this command
 * exists to make a demo removable, not to prune live data.
 */
class ClearDemoData extends Command
{
    protected $signature = 'demo:clear {--force : Skip the confirmation prompt}';

    protected $description = 'Delete every account and record created by DemoDataSeeder';

    public function handle(): int
    {
        if (app()->isProduction()) {
            $this->error('Refusing to run in production.');
            return self::FAILURE;
        }

        $users = User::where('email', 'like', '%@' . DemoDataSeeder::DOMAIN)->get();

        if ($users->isEmpty()) {
            $this->info('No demo data found.');
            return self::SUCCESS;
        }

        $ids  = $users->pluck('id');
        $jobs = DB::table('jobs_posts')->whereIn('employer_id', $ids)->pluck('id');

        $this->line("Demo accounts: {$users->count()}");
        $this->line("Their job posts: {$jobs->count()}");

        if (! $this->option('force') && ! $this->confirm('Delete all of it?', true)) {
            $this->info('Nothing deleted.');
            return self::SUCCESS;
        }

        DB::transaction(function () use ($ids, $jobs) {
            // Applications reference both a job and a worker, so a demo worker
            // may hold applications against a job that is not being deleted.
            DB::table('applications')
                ->whereIn('job_id', $jobs)
                ->orWhereIn('worker_id', $ids)
                ->delete();

            DB::table('job_skills')->whereIn('job_id', $jobs)->delete();
            DB::table('jobs_posts')->whereIn('id', $jobs)->delete();

            // The rest cascade from users, but deleting them explicitly keeps
            // this correct if a foreign key is ever changed.
            DB::table('verifications')->whereIn('user_id', $ids)->delete();
            DB::table('worker_profiles')->whereIn('user_id', $ids)->delete();
            DB::table('employer_profiles')->whereIn('user_id', $ids)->delete();
            DB::table('users')->whereIn('id', $ids)->delete();
        });

        $this->info('Demo data removed.');

        return self::SUCCESS;
    }
}
