<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

/**
 * Times every endpoint the app actually calls, and counts the queries each one
 * runs to get there.
 *
 * Wall time alone says "this is slow" without saying why, so this separates the
 * two costs that make up a response: time spent waiting on MySQL, and time
 * spent in PHP. It also records how often the *same* SQL is issued inside one
 * request, because a query repeated thirty times with a different id is the
 * signature of an N+1 — the single most common reason a list screen in an app
 * like this feels sluggish, and one that never shows up when you test with five
 * rows in the table.
 *
 * Runs in-process, so there is no network in the measurement. That is
 * deliberate: this is here to find slow *code*, and tunnel latency would bury
 * a 40ms regression under 300ms of noise.
 *
 *   php artisan perf:audit
 *   php artisan perf:audit --reps=5 --slow=250
 */
class PerfAudit extends Command
{
    protected $signature = 'perf:audit
        {--reps=3     : Times to run each endpoint; the median is reported}
        {--slow=300   : Flag responses slower than this many ms}
        {--queries=15 : Flag responses issuing more than this many queries}';

    protected $description = 'Time every major endpoint and count its queries, to find delays and N+1s';

    /** @var list<array{sql:string,time:float}> */
    private array $log = [];

    private bool $recording = false;

    public function handle(): int
    {
        $employer = User::where('email', 'boss@scenario.kaya.local')->first();
        $worker = User::where('email', 'hired@scenario.kaya.local')->first();

        if (! $employer || ! $worker) {
            $this->error('Scenario accounts are missing. Run: php artisan scenarios:seed');

            return self::FAILURE;
        }

        $job = JobPost::where('employer_id', $employer->id)->latest('id')->first();
        $application = Application::whereIn('job_id', JobPost::where('employer_id', $employer->id)->pluck('id'))
            ->where('worker_id', $worker->id)->first();
        $conversation = Conversation::where('worker_id', $worker->id)->first();

        $employerToken = $employer->createToken('perf-audit')->plainTextToken;
        $workerToken = $worker->createToken('perf-audit')->plainTextToken;

        DB::listen(function ($q) {
            if ($this->recording) {
                $this->log[] = ['sql' => $q->sql, 'time' => $q->time];
            }
        });

        $probes = $this->probes($job, $application, $conversation, $worker, $employerToken, $workerToken);

        // One throwaway pass. The first request through the kernel pays for
        // autoloading, config and container warm-up, which would otherwise be
        // charged to whichever endpoint happens to be listed first.
        $this->line('  Warming up...');
        $this->fire('GET', '/api/v1/me', $workerToken);

        $reps = max(1, (int) $this->option('reps'));
        $slowMs = (float) $this->option('slow');
        $maxQueries = (int) $this->option('queries');

        $results = [];
        $bar = $this->output->createProgressBar(count($probes));
        $bar->start();

        foreach ($probes as $probe) {
            [$label, $method, $path, $token] = $probe;

            $runs = [];
            for ($i = 0; $i < $reps; $i++) {
                $runs[] = $this->fire($method, $path, $token);
            }

            // Median, not mean — one GC pause should not define the number.
            usort($runs, fn ($a, $b) => $a['ms'] <=> $b['ms']);
            $median = $runs[intdiv(count($runs), 2)];

            $results[] = [
                'label' => $label,
                'path' => $path,
                'status' => $median['status'],
                'ms' => $median['ms'],
                'dbMs' => $median['dbMs'],
                'queries' => $median['queries'],
                'worstRepeat' => $median['worstRepeat'],
                'repeatSql' => $median['repeatSql'],
                'bytes' => $median['bytes'],
            ];

            $bar->advance();
        }

        $bar->finish();
        $this->newLine(2);

        $this->report($results, $slowMs, $maxQueries);

        // Tokens were minted only to drive this audit.
        DB::table('personal_access_tokens')->where('name', 'perf-audit')->delete();

        return self::SUCCESS;
    }

    /**
     * Dispatch one request through the full middleware stack and measure it.
     *
     * @return array{status:int,ms:float,dbMs:float,queries:int,worstRepeat:int,repeatSql:string,bytes:int}
     */
    private function fire(string $method, string $path, ?string $token): array
    {
        // Sanctum caches the resolved user on the guard; without this every
        // request after the first would be measured while already authenticated.
        Auth::forgetGuards();

        $request = Request::create($path, $method);
        $request->headers->set('Accept', 'application/json');
        if ($token) {
            $request->headers->set('Authorization', 'Bearer '.$token);
        }

        $this->log = [];
        $this->recording = true;

        $start = microtime(true);
        $response = app(Kernel::class)->handle($request);
        $ms = (microtime(true) - $start) * 1000;

        $this->recording = false;

        $dbMs = array_sum(array_column($this->log, 'time'));

        // How many times the same statement ran inside this one request.
        $counts = array_count_values(array_column($this->log, 'sql'));
        arsort($counts);
        $worstRepeat = $counts ? reset($counts) : 0;
        $repeatSql = $counts ? (string) key($counts) : '';

        return [
            'status' => $response->getStatusCode(),
            'ms' => round($ms, 1),
            'dbMs' => round($dbMs, 1),
            'queries' => count($this->log),
            'worstRepeat' => $worstRepeat,
            'repeatSql' => $repeatSql,
            'bytes' => strlen((string) $response->getContent()),
        ];
    }

    /** @return list<array{0:string,1:string,2:string,3:?string}> */
    private function probes(
        ?JobPost $job,
        ?Application $application,
        ?Conversation $conversation,
        User $worker,
        string $employerToken,
        string $workerToken,
    ): array {
        $p = [
            ['Session restore (every cold start)', 'GET', '/api/v1/me', $workerToken],
            ['Job feed (worker home)', 'GET', '/api/v1/jobs', $workerToken],
            ['Job feed page 2', 'GET', '/api/v1/jobs?page=2', $workerToken],
            ['Job feed, searched', 'GET', '/api/v1/jobs?q=roof', $workerToken],
            ['Worker browse (employer home)', 'GET', '/api/v1/workers', $employerToken],
            ['Worker profile', 'GET', '/api/v1/workers/'.$worker->id, $employerToken],
            ['My applications (worker)', 'GET', '/api/v1/my-applications', $workerToken],
            ['My jobs (employer)', 'GET', '/api/v1/jobs/my', $employerToken],
            ['Saved jobs', 'GET', '/api/v1/saved-jobs', $workerToken],
            ['My invitations', 'GET', '/api/v1/my-invitations', $workerToken],
            ['Conversation list', 'GET', '/api/v1/conversations', $workerToken],
            ['Notification list', 'GET', '/api/v1/notifications', $workerToken],
            ['Unread badge (polled)', 'GET', '/api/v1/notifications/unread-count', $workerToken],
            ['Categories (picker)', 'GET', '/api/v1/categories', $workerToken],
            ['Skills (picker)', 'GET', '/api/v1/skills', $workerToken],
            ['Location search (typeahead)', 'GET', '/api/v1/locations/search?q=Urda', $workerToken],
            ['Realtime config', 'GET', '/api/v1/realtime/config', $workerToken],
            ['Profile views summary', 'GET', '/api/v1/profile-views/summary', $workerToken],
        ];

        if ($job) {
            $p[] = ['Job details', 'GET', '/api/v1/jobs/'.$job->id, $workerToken];
            $p[] = ['Applicant list', 'GET', '/api/v1/jobs/'.$job->id.'/applicants', $employerToken];
            $p[] = ['Review status', 'GET', '/api/v1/jobs/'.$job->id.'/review-status', $workerToken];
        }

        if ($conversation) {
            $p[] = ['Chat messages', 'GET', '/api/v1/conversations/'.$conversation->id.'/messages', $workerToken];
        }

        if ($application) {
            $p[] = ['Tracking poll', 'GET', '/api/v1/applications/'.$application->id.'/tracking', $employerToken];
        }

        return $p;
    }

    /** @param list<array<string,mixed>> $results */
    private function report(array $results, float $slowMs, int $maxQueries): void
    {
        $rows = [];
        foreach ($results as $r) {
            $flags = [];
            if ($r['ms'] > $slowMs) {
                $flags[] = 'SLOW';
            }
            if ($r['queries'] > $maxQueries) {
                $flags[] = 'QUERIES';
            }
            if ($r['worstRepeat'] >= 5) {
                $flags[] = 'N+1';
            }
            if ($r['status'] >= 400) {
                $flags[] = 'HTTP '.$r['status'];
            }
            if ($r['bytes'] > 200_000) {
                $flags[] = 'PAYLOAD';
            }

            $rows[] = [
                $r['label'],
                $r['status'],
                number_format($r['ms'], 0).'ms',
                number_format($r['dbMs'], 0).'ms',
                $r['queries'],
                $r['worstRepeat'] > 1 ? 'x'.$r['worstRepeat'] : '-',
                $this->humanBytes($r['bytes']),
                $flags ? implode(' ', $flags) : '',
            ];
        }

        $this->table(
            ['Endpoint', 'HTTP', 'Total', 'In DB', 'Queries', 'Worst repeat', 'Size', 'Flags'],
            $rows,
        );

        $this->newLine();
        $this->line('  Total = wall time in PHP, no network. In DB = time inside MySQL.');
        $this->line('  A large gap between them is PHP work; a small gap means the queries are the cost.');
        $this->line('  "Worst repeat" is the same SQL run N times in one request - the N+1 signature.');
        $this->newLine();

        // The detail that actually tells you what to fix.
        foreach ($results as $r) {
            if ($r['worstRepeat'] >= 5) {
                $this->line('  N+1 in '.$r['label'].'  ('.$r['worstRepeat'].' identical queries)');
                $this->line('    '.substr($r['repeatSql'], 0, 160));
                $this->newLine();
            }
        }

        $slow = array_filter($results, fn ($r) => $r['ms'] > $slowMs);
        $heavy = array_filter($results, fn ($r) => $r['queries'] > $maxQueries);

        $this->line(sprintf(
            '  %d endpoints measured | %d slower than %dms | %d over %d queries',
            count($results), count($slow), $slowMs, count($heavy), $maxQueries,
        ));
    }

    private function humanBytes(int $b): string
    {
        if ($b > 1_048_576) {
            return round($b / 1_048_576, 1).'MB';
        }
        if ($b > 1024) {
            return round($b / 1024).'KB';
        }

        return $b.'B';
    }
}
