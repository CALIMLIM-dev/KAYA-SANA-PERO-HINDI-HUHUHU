<?php

namespace App\Console\Commands;

use App\Models\SystemSetting;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Finishes the sample population for the defense.

    The sample accounts are made through the real API, like a phone, so the
    server's own code runs - and so everything is dated today. This marks
    them as demo (one switch can hide them after the defense; nothing is
    deleted) and pushes their history back, so a finished job reads as
    finished weeks ago and the analytics have a spread.

    Each job moves as one: the post, its hires, its chat and its reviews by
    the same number of days, so nothing happens before what caused it. Open
    jobs keep their deadline, so they stay open. Board posts move with their
    comments. Runs once per domain.

        php artisan kaya:demo-finish sample.kaya.test
*/
class DemoFinish extends Command
{
    protected $signature = 'kaya:demo-finish {domain : email domain of the sample accounts} {--max-days=45}';

    protected $description = 'Mark the sample accounts as demo and spread their history over past weeks';

    public function handle(): int
    {
        $domain = ltrim((string) $this->argument('domain'), '@');
        $flag = 'demo.finished.' . $domain;
        if (SystemSetting::get($flag) !== null) {
            $this->warn("Already done for $domain.");

            return self::SUCCESS;
        }

        $ids = DB::table('users')->where('email', 'like', '%@' . $domain)->pluck('id');
        if ($ids->isEmpty()) {
            $this->error("No accounts on $domain.");

            return self::FAILURE;
        }
        DB::table('users')->whereIn('id', $ids)->update(['is_demo' => true]);

        $max = max(1, (int) $this->option('max-days'));
        $jobs = DB::table('jobs_posts')->whereIn('employer_id', $ids)->get(['id', 'status']);
        foreach ($jobs as $job) {
            $days = 2 + ($job->id * 7919) % $max; // fixed per job, spread over the range
            $open = in_array($job->status, ['open', 'in_progress'], true);
            $this->shift('jobs_posts', 'id', [$job->id], $days, $open ? ['end_date', 'expires_at', 'start_date'] : []);
            $apps = DB::table('applications')->where('job_id', $job->id)->pluck('id')->all();
            $this->shift('applications', 'id', $apps, $days);
            $this->shift('reviews', 'job_id', [$job->id], $days);
            $threads = DB::table('conversations')->where('job_id', $job->id)->pluck('id')->all();
            $this->shift('messages', 'conversation_id', $threads, $days, ['read_at', 'checked_at']);
        }

        $posts = DB::table('community_posts')->whereIn('user_id', $ids)->get(['id', 'status']);
        foreach ($posts as $post) {
            $days = 1 + ($post->id * 104729) % $max;
            // A live post keeps its end date, so it stays up; the rest move with it.
            $this->shift('community_posts', 'id', [$post->id], $days, $post->status === 'live' ? ['expires_at'] : []);
            $this->shift('community_comments', 'community_post_id', [$post->id], min($days, 1));
        }

        // Accounts made before anything they did.
        $back = $max + 14;
        DB::table('users')->whereIn('id', $ids)->update(['created_at' => DB::getDriverName() === 'sqlite'
            ? DB::raw("datetime(created_at, '-{$back} days')")
            : DB::raw("DATE_SUB(created_at, INTERVAL {$back} DAY)")]);

        SystemSetting::updateOrCreate(['key' => $flag], ['value' => now()->toDateTimeString(), 'label' => 'Demo population finished', 'group' => 'demo']);
        $this->info(sprintf('%d accounts marked demo; %d jobs and %d board posts moved back.', $ids->count(), $jobs->count(), $posts->count()));

        return self::SUCCESS;
    }

    /** Moves every date and time column on these rows back by $days, except $keep. */
    private function shift(string $table, string $key, array $values, int $days, array $keep = []): void
    {
        if ($values === [] || ! Schema::hasTable($table)) {
            return;
        }
        $sets = [];
        foreach (Schema::getColumns($table) as $col) {
            $type = strtolower($col['type_name'] ?? $col['type'] ?? '');
            if (in_array($col['name'], $keep, true) || ! preg_match('/date|time/', $type)) {
                continue;
            }
            $sets[$col['name']] = DB::getDriverName() === 'sqlite'
                ? DB::raw("datetime({$col['name']}, '-{$days} days')")
                : DB::raw("DATE_SUB({$col['name']}, INTERVAL {$days} DAY)");
        }
        if ($sets !== []) {
            DB::table($table)->whereIn($key, $values)->update($sets);
        }
    }
}
