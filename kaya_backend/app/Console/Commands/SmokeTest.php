<?php

namespace App\Console\Commands;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\Skill;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Console\Command;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

/*
    Drives the running server the way the phone does, and fails loudly.

    The unit suite runs on SQLite in memory with no Reverb, no tunnel and no
    device, so a whole class of defect is invisible to it. Every bug found on
    23 Aug was of that class:

      - posting a job took 30s because a broadcast to a Reverb that was not
        listening had no HTTP timeout, and the phone reported it to the user
        as "no internet connection"
      - the same request then threw 1054 out of NotificationService::jobMatched
      - signing out 401'd once a token had been revoked, so a suspended client
        could never finish signing out and polled a rejected request forever

    Each is caught here in well under a second. Run it after anything that
    touches posting, auth or notifications:

        php artisan kaya:smoke
*/
class SmokeTest extends Command
{
    protected $signature = 'kaya:smoke {--base=http://127.0.0.1:8000 : server to drive}';

    protected $description = 'Drive the running API end to end and assert status codes and response times';

    /** Anything slower than this is treated as broken, not slow. */
    private const SLOW_MS = 3000;

    private int $passed = 0;
    private array $failures = [];
    private array $cleanup = [];

    public function handle(): int
    {
        $base = rtrim((string) $this->option('base'), '/');
        $this->line('driving ' . $base);
        $this->newLine();

        try {
            $this->checkAuthIsEnforced($base);
            $this->checkLoginRejectsGarbage($base);
            $this->checkLogoutWithoutToken($base);
            $this->checkBroadcastCannotHang();
            $this->checkAuthenticatedFlow($base);
            $this->checkRevokedTokenIsRefusedFast($base);
        } catch (\Throwable $e) {
            $this->failures[] = 'smoke run aborted: ' . $e->getMessage();
        } finally {
            $this->tidyUp();
        }

        $this->newLine();
        foreach ($this->failures as $f) {
            $this->line('  <fg=red>FAIL</>  ' . $f);
        }
        $this->line(sprintf(
            '  %d passed, %d failed',
            $this->passed,
            count($this->failures)
        ));

        return $this->failures ? self::FAILURE : self::SUCCESS;
    }

    // ---------------------------------------------------------------- checks

    private function checkAuthIsEnforced(string $base): void
    {
        $this->assertCall(
            'protected endpoint refuses an anonymous caller',
            fn () => Http::acceptJson()->get("$base/api/v1/jobs"),
            401
        );
    }

    private function checkLoginRejectsGarbage(string $base): void
    {
        $this->assertCall(
            'login refuses bad credentials without a 500',
            fn () => Http::acceptJson()->post("$base/api/v1/login", [
                'email' => 'definitely-not-a-user@example.invalid',
                'password' => 'wrong-password',
            ]),
            [401, 422]
        );
    }

    /*
        Suspending an account deletes its tokens, so the client that most needs
        to sign out is the one that no longer can. This 401'd until 23 Aug and
        the phone retried it every 30 seconds forever.
    */
    private function checkLogoutWithoutToken(string $base): void
    {
        $this->assertCall(
            'logout succeeds with no token at all',
            fn () => Http::acceptJson()->post("$base/api/v1/logout"),
            200
        );

        $this->assertCall(
            'logout succeeds with a revoked token',
            fn () => Http::acceptJson()
                ->withToken('999|deadbeefdeadbeefdeadbeefdeadbeef')
                ->post("$base/api/v1/logout"),
            200
        );
    }

    /*
        Not an HTTP check: it asserts the configuration cannot reproduce the
        30-second stall. Either broadcasting is off, or its client has a
        timeout. A driver pointed at an absent Reverb with no timeout is the
        exact shape of the outage.
    */
    private function checkBroadcastCannotHang(): void
    {
        $driver = config('broadcasting.default');
        $opts = config("broadcasting.connections.$driver.client_options", []);
        $timeout = $opts['timeout'] ?? null;

        if (in_array($driver, ['null', 'log'], true) || ($timeout !== null && $timeout <= 5)) {
            $this->pass(sprintf(
                'broadcasting cannot stall a write (driver=%s, timeout=%s)',
                $driver,
                $timeout === null ? 'n/a' : $timeout . 's'
            ));
            return;
        }

        $this->failures[] = sprintf(
            'broadcast driver "%s" has no client timeout - a dead Reverb will hang every write',
            $driver
        );
    }

    /*
        The one that matters: post a job as a real employer. This exercises
        validation, the insert, the broadcast and jobMatched() in one request -
        which is every component that failed on 23 Aug.
    */
    private function checkAuthenticatedFlow(string $base): void
    {
        $employer = User::whereHas('employerProfile')->where('is_suspended', false)->first();
        if (!$employer) {
            $this->failures[] = 'no employer account to test with';
            return;
        }

        $token = $employer->createToken('kaya-smoke')->plainTextToken;
        $this->cleanup[] = fn () => $employer->tokens()->where('name', 'kaya-smoke')->delete();

        $api = fn (): PendingRequest => Http::acceptJson()->withToken($token);

        $this->assertCall('/me returns the signed-in account', fn () => $api()->get("$base/api/v1/me"), 200);
        $this->assertCall('job feed loads', fn () => $api()->get("$base/api/v1/jobs"), 200);
        $this->assertCall('notifications load', fn () => $api()->get("$base/api/v1/notifications"), 200);

        $category = Category::query()->first();
        $location = Location::query()->first();
        if (!$category || !$location) {
            $this->failures[] = 'no category/location seeded - cannot test posting';
            return;
        }

        // A skill on the job is what drags jobMatched() into the request, and
        // jobMatched() is where the 1054 lived. Posting without one would pass
        // while still being broken.
        $skill = Skill::query()->where('category_id', $category->id)->first()
            ?? Skill::query()->first();

        $before = JobPost::max('id') ?? 0;

        $response = $this->assertCall(
            'POST /jobs succeeds and returns quickly',
            fn () => $api()->attach(
                'photos[]',
                $this->onePixelPng(),
                'smoke.png'
            )->post("$base/api/v1/jobs", array_filter([
                'title' => '[smoke test] ignore me',
                'description' => 'Automated smoke test. Deleted immediately.',
                'category_id' => $category->id,
                'budget_min' => 500,
                'budget_max' => 800,
                'budget_period' => 'daily',
                'location' => 'Smoke test location',
                'location_id' => $location->id,
                'start_date' => now()->addDay()->toDateString(),
                'required_skill_ids' => $skill ? [$skill->id] : null,
            ], fn ($v) => $v !== null)),
            201
        );

        // Whatever it was created as, it must not survive this command.
        $created = JobPost::where('id', '>', $before)->pluck('id');
        if ($created->isNotEmpty()) {
            $this->cleanup[] = function () use ($created) {
                UserNotification::whereIn('reference_id', $created)
                    ->where('reference_type', 'job')->delete();
                DB::table('job_skills')->whereIn('job_id', $created)->delete();
                JobPost::whereIn('id', $created)->forceDelete();
            };
        }

        if ($response && $response->successful()) {
            $this->pass('posted job was cleaned up');
        }
    }

    private function checkRevokedTokenIsRefusedFast(string $base): void
    {
        $user = User::whereHas('employerProfile')->first();
        if (!$user) { return; }

        $token = $user->createToken('kaya-smoke-revoked')->plainTextToken;
        $user->tokens()->where('name', 'kaya-smoke-revoked')->delete();   // kill it immediately

        $this->assertCall(
            'a revoked token is refused, not hung',
            fn () => Http::acceptJson()->withToken($token)->get("$base/api/v1/notifications"),
            401
        );
    }

    // --------------------------------------------------------------- plumbing

    /** @param int|int[] $expected */
    private function assertCall(string $label, callable $call, int|array $expected)
    {
        $want = (array) $expected;
        $started = microtime(true);

        try {
            $response = $call();
        } catch (\Throwable $e) {
            $this->failures[] = sprintf('%s - request threw: %s', $label, $e->getMessage());
            return null;
        }

        $ms = (int) round((microtime(true) - $started) * 1000);
        $status = $response->status();

        if (!in_array($status, $want, true)) {
            $this->failures[] = sprintf(
                '%s - got %d, expected %s (%dms) %s',
                $label, $status, implode('/', $want), $ms,
                mb_substr(strip_tags((string) $response->body()), 0, 160)
            );
            return $response;
        }

        if ($ms > self::SLOW_MS) {
            $this->failures[] = sprintf(
                '%s - correct (%d) but took %dms, over the %dms limit',
                $label, $status, $ms, self::SLOW_MS
            );
            return $response;
        }

        $this->pass(sprintf('%s (%d, %dms)', $label, $status, $ms));

        return $response;
    }

    private function pass(string $label): void
    {
        $this->passed++;
        $this->line('  <fg=green>PASS</>  ' . $label);
    }

    private function tidyUp(): void
    {
        foreach (array_reverse($this->cleanup) as $task) {
            try {
                $task();
            } catch (\Throwable $e) {
                $this->failures[] = 'cleanup failed: ' . $e->getMessage();
            }
        }
    }

    /** Smallest valid PNG, so the photo rule is satisfied without a fixture. */
    private function onePixelPng(): string
    {
        return base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
        );
    }
}
