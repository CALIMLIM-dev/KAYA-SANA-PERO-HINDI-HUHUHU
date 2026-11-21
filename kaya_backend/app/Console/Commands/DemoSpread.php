<?php

namespace App\Console\Commands;

use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Spreads the sample accounts' history over the past months.
 *
 * The sample data was created on a few days, so every analytics trend read
 * as one spike and every comparison as a fall. This moves it back in time the
 * way a growing app looks: sign-ups thin at first and rising, each account's
 * jobs, chats and payments after it joined.
 *
 * Nothing changes order. A job and everything that hangs off it (its
 * applications, chat, schedule, reviews, live-location trail) move by one
 * amount together. Work still under way stays recent: open jobs and hires in
 * progress move at most 30 days, so no deadline clock or post expiry is
 * tripped; live board posts stay within their week. Only accounts with an
 * email at the given domain are touched.
 *
 *     php artisan kaya:demo-spread sample.kaya.test --dry
 *     php artisan kaya:demo-spread sample.kaya.test
 */
class DemoSpread extends Command
{
    protected $signature = 'kaya:demo-spread {domain : Email domain of the sample accounts} {--days=150 : How far back the first sign-up goes} {--dry : Show what would change without writing}';

    protected $description = 'Spread the sample accounts\' dates over the past months so the analytics read naturally';

    private CarbonImmutable $now;

    /** @var array<string, list<string>> */
    private array $timeColumns = [];

    private int $changed = 0;

    public function handle(): int
    {
        $domain = ltrim((string) $this->argument('domain'), '@');
        $days = max(30, (int) $this->option('days'));
        $dry = (bool) $this->option('dry');
        $this->now = CarbonImmutable::now();
        $start = $this->now->subDays($days);

        $users = DB::table('users')->where('email', 'like', "%@{$domain}")->orderBy('id')->get(['id', 'created_at']);
        if ($users->isEmpty()) {
            $this->warn("No accounts at @{$domain}.");

            return self::FAILURE;
        }

        $run = function () use ($users, $start, $days) {
            // ── Sign-ups: thin at first, rising (join time grows with the square root of rank) ──
            $join = [];
            $n = $users->count();
            foreach ($users->values() as $i => $u) {
                $f = ($i + 1) / $n;
                $at = $start->addSeconds((int) (sqrt($f) * ($days - 2) * 86400))->addMinutes($this->jitter("u{$u->id}", 0, 600));
                $join[$u->id] = $at->min($this->now->subDay());
                $this->set('users', $u->id, ['created_at' => $join[$u->id]]);
                foreach (['worker_profiles', 'employer_profiles'] as $t) {
                    DB::table($t)->where('user_id', $u->id)->pluck('id')
                        ->each(fn ($id) => $this->set($t, $id, ['created_at' => $join[$u->id]->addMinutes(20)]));
                }
                DB::table('verifications')->where('user_id', $u->id)->get(['id', 'created_at'])
                    ->each(fn ($v) => $this->shift('verifications', [$v->id], $this->deltaTo($v->created_at, $join[$u->id]->addHours(6 + $this->jitter("v{$v->id}", 0, 60)))));
            }

            // ── Jobs, each with everything that hangs off it ──
            $jobs = DB::table('jobs_posts')->whereIn('employer_id', array_keys($join))->get(['id', 'employer_id', 'status', 'created_at']);
            foreach ($jobs as $job) {
                $apps = DB::table('applications')->where('job_id', $job->id)->get(['id', 'status']);
                $live = in_array($job->status, ['open', 'in_progress'], true) || $apps->contains('status', 'accepted');
                $joined = $join[$job->employer_id];
                $from = $live ? $joined->max($this->now->subDays(30)) : $joined->addDay();
                $to = $live ? $this->now->subDay() : $this->now->subDays(14)->max($from->addDay());
                $target = $this->between("j{$job->id}", $from, $to);
                $delta = $this->deltaTo($job->created_at, $target);
                if ($delta === 0) {
                    continue;
                }

                $this->shift('jobs_posts', [$job->id], $delta, $live ? ['expires_at'] : []);
                $appIds = $apps->pluck('id')->all();
                $this->shift('applications', $appIds, $delta);
                $convIds = DB::table('conversations')->where('job_id', $job->id)->pluck('id')->all();
                $this->shift('conversations', $convIds, $delta);
                foreach (array_chunk($convIds, 200) as $chunk) {
                    $this->shift('messages', DB::table('messages')->whereIn('conversation_id', $chunk)->pluck('id')->all(), $delta);
                }
                $this->shift('schedule_proposals', DB::table('schedule_proposals')->where('job_id', $job->id)->pluck('id')->all(), $delta, [], ! $live);
                $this->shift('reviews', DB::table('reviews')->where('job_id', $job->id)->pluck('id')->all(), $delta);
                $sessions = $appIds ? DB::table('job_tracking_sessions')->whereIn('application_id', $appIds)->pluck('id')->all() : [];
                $this->shift('job_tracking_sessions', $sessions, $delta);
                foreach (array_chunk($sessions, 200) as $chunk) {
                    $this->shift('job_location_pings', DB::table('job_location_pings')->whereIn('tracking_session_id', $chunk)->pluck('id')->all(), $delta);
                }
            }

            // ── Board posts and their comments and likes ──
            $posts = DB::table('community_posts')->whereIn('user_id', array_keys($join))->get(['id', 'user_id', 'status', 'created_at']);
            foreach ($posts as $post) {
                $joined = $join[$post->user_id];
                $recent = in_array($post->status, ['live', 'pending'], true);
                $from = $recent ? $joined->max($this->now->subDays($post->status === 'live' ? 6 : 2)) : $joined->addDay();
                $to = $recent ? $this->now->subHours(2) : $this->now->subDays(10)->max($from->addDay());
                $delta = $this->deltaTo($post->created_at, $this->between("p{$post->id}", $from, $to));
                if ($delta === 0) {
                    continue;
                }
                $this->shift('community_posts', [$post->id], $delta, $recent ? ['expires_at'] : []);
                $this->shift('community_comments', DB::table('community_comments')->where('community_post_id', $post->id)->pluck('id')->all(), $delta);
                if (Schema::hasTable('community_post_likes') && Schema::hasColumn('community_post_likes', 'id')) {
                    $this->shift('community_post_likes', DB::table('community_post_likes')->where('community_post_id', $post->id)->pluck('id')->all(), $delta);
                }
            }

            // ── A person's own records: spread from when they joined to now, order kept ──
            foreach (['credit_transactions' => 'user_id', 'credit_payments' => 'user_id', 'reports' => 'reporter_id',
                'strikes' => 'user_id', 'support_threads' => 'user_id', 'badge_rewards' => 'user_id', 'boosts' => 'user_id'] as $table => $owner) {
                if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $owner)) {
                    continue;
                }
                foreach ($join as $userId => $joined) {
                    $rows = DB::table($table)->where($owner, $userId)->orderBy('created_at')->get(['id', 'created_at']);
                    if ($rows->isEmpty()) {
                        continue;
                    }
                    $first = CarbonImmutable::parse($rows->first()->created_at);
                    $span = max(1, CarbonImmutable::parse($rows->last()->created_at)->getTimestamp() - $first->getTimestamp());
                    $room = max(3600, $this->now->getTimestamp() - $joined->addHour()->getTimestamp());
                    foreach ($rows as $row) {
                        $share = (CarbonImmutable::parse($row->created_at)->getTimestamp() - $first->getTimestamp()) / $span;
                        $target = $joined->addHour()->addSeconds((int) ($share * $room * 0.95));
                        $this->shift($table, [$row->id], $this->deltaTo($row->created_at, $target));
                    }
                }
            }
        };

        if ($dry) {
            DB::beginTransaction();
            $run();
            DB::rollBack();
            $this->info("Dry run: {$this->changed} rows would change for {$users->count()} sample accounts. Nothing written.");
        } else {
            DB::transaction($run);
            $this->info("Spread {$this->changed} rows over {$days} days for {$users->count()} sample accounts.");
        }

        return self::SUCCESS;
    }

    /** Seconds from $at to $target. */
    private function deltaTo(?string $at, CarbonImmutable $target): int
    {
        return $at === null ? 0 : $target->getTimestamp() - CarbonImmutable::parse($at)->getTimestamp();
    }

    /** A steady pseudo-random point between two times, the same on every run for the same key. */
    private function between(string $key, CarbonImmutable $from, CarbonImmutable $to): CarbonImmutable
    {
        $span = max(0, $to->getTimestamp() - $from->getTimestamp());

        return $from->addSeconds($span === 0 ? 0 : crc32($key) % $span);
    }

    private function jitter(string $key, int $min, int $max): int
    {
        return $min + crc32($key) % max(1, $max - $min);
    }

    /** Sets columns on one row outright. */
    private function set(string $table, int $id, array $values): void
    {
        $values = array_map(fn ($v) => $v instanceof CarbonImmutable ? $v->toDateTimeString() : $v, $values);
        $this->changed += DB::table($table)->where('id', $id)->update($values) > 0 ? 1 : 0;
    }

    /**
     * Moves every time column of these rows by $delta seconds, never past now.
     * Columns in $keep stay as they are; a date column (such as a schedule's
     * day) moves only when $moveDates is set.
     */
    private function shift(string $table, array $ids, int $delta, array $keep = [], bool $moveDates = false): void
    {
        if ($ids === [] || $delta === 0 || ! Schema::hasTable($table)) {
            return;
        }
        $columns = array_values(array_diff($this->timeColumns($table, $moveDates), $keep));
        foreach (array_chunk($ids, 200) as $chunk) {
            foreach (DB::table($table)->whereIn('id', $chunk)->get(array_merge(['id'], $columns)) as $row) {
                $values = [];
                foreach ($columns as $c) {
                    if ($row->{$c} === null) {
                        continue;
                    }
                    $moved = CarbonImmutable::parse($row->{$c})->addSeconds($delta)->min($this->now);
                    $values[$c] = strlen((string) $row->{$c}) <= 10 ? $moved->toDateString() : $moved->toDateTimeString();
                }
                if ($values) {
                    $this->changed += DB::table($table)->where('id', $row->id)->update($values) > 0 ? 1 : 0;
                }
            }
        }
    }

    /** @return list<string> */
    private function timeColumns(string $table, bool $withDates): array
    {
        $key = $table . ($withDates ? '+d' : '');

        return $this->timeColumns[$key] ??= collect(Schema::getColumns($table))
            ->filter(fn ($c) => in_array(strtolower($c['type_name']), $withDates
                ? ['timestamp', 'datetime', 'date']
                : ['timestamp', 'datetime'], true))
            // Deadlines and the post's own life are not history.
            ->reject(fn ($c) => in_array($c['name'], ['end_date', 'start_date', 'deadline', 'work_starts_on', 'email_verified_at'], true))
            ->pluck('name')->values()->all();
    }
}
