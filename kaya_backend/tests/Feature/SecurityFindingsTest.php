<?php

namespace Tests\Feature;

use App\Mail\PasswordResetMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The QA audit's findings, one test each. Every test here failed before
    its fix (QA-AUDIT.md, Step 2).
*/
class SecurityFindingsTest extends TestCase
{
    use RefreshDatabase;

    private function maria(): User
    {
        return User::factory()->create([
            'email' => 'maria@example.com', 'password' => Hash::make('Old!Passw0rd'),
        ]);
    }

    /** Asks for a reset code and returns the one that was emailed. */
    private function resetCode(string $email = 'maria@example.com'): string
    {
        Mail::fake();
        $this->postJson('/api/v1/forgot-password', ['email' => $email])->assertOk();
        $code = null;
        Mail::assertSent(PasswordResetMail::class, function ($m) use (&$code) {
            $code = $m->resetCode;

            return true;
        });

        return $code;
    }

    private function wrong(string $code): string
    {
        return str_pad((string) (((int) $code + 1) % 1000000), 6, '0', STR_PAD_LEFT);
    }

    /*
        Finding 1. A reset code could be guessed for its whole fifteen
        minutes; only the per-IP limit slowed it down. Five wrong tries now
        destroy it, the right code included.
    */
    #[Test]
    public function finding_1_five_wrong_reset_codes_destroy_the_code(): void
    {
        $this->maria();
        $code = $this->resetCode();

        foreach (range(1, 5) as $i) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])
                ->postJson('/api/v1/verify-reset-code', ['email' => 'maria@example.com', 'code' => $this->wrong($code)])
                ->assertStatus(422);
        }

        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.9'])
            ->postJson('/api/v1/verify-reset-code', ['email' => 'maria@example.com', 'code' => $code])
            ->assertStatus(422);
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.9'])->postJson('/api/v1/reset-password', [
            'email' => 'maria@example.com', 'code' => $code,
            'password' => 'New!Passw0rd9', 'password_confirmation' => 'New!Passw0rd9',
        ])->assertStatus(422);

        $this->assertTrue(Hash::check('Old!Passw0rd', User::first()->password));
    }

    /*
        Finding 2. trustProxies('*') believed any X-Forwarded-For header, so
        a new made-up address per request was a new rate-limit bucket. From
        a real (non-local) address, the header is now ignored.
    */
    #[Test]
    public function finding_2_a_made_up_forwarded_address_does_not_reset_the_login_limit(): void
    {
        $refused = false;
        foreach (range(1, 25) as $i) {
            $status = $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7'])
                ->withHeaders(['X-Forwarded-For' => "198.51.100.{$i}"])
                ->postJson('/api/v1/login', ['email' => "nobody{$i}@example.com", 'password' => 'wrong-password-1'])
                ->status();
            if ($status === 429) {
                $refused = true;
                break;
            }
        }

        $this->assertTrue($refused, 'rotating X-Forwarded-For bought unlimited login attempts');
    }

    /*
        Finding 2. Even with many real addresses, one account takes a
        bounded number of password guesses a minute.
    */
    #[Test]
    public function finding_2_one_account_is_limited_whatever_the_address(): void
    {
        $this->maria();

        $statuses = [];
        foreach (range(1, 12) as $i) {
            $statuses[] = $this->withServerVariables(['REMOTE_ADDR' => "203.0.113.{$i}"])
                ->postJson('/api/v1/login', ['email' => 'maria@example.com', 'password' => "wrong-password-{$i}"])
                ->status();
        }

        $this->assertContains(429, $statuses, 'one account took 12 guesses a minute from 12 addresses');
    }

    /*
        Finding 3. Login, sign-up and the reset steps shared one counter of
        10 a minute per address, so a password reset (and a code box that
        could send the code twice) used it up and the next sign-in was
        refused on its first try.
    */
    #[Test]
    public function finding_3_a_password_reset_does_not_use_up_the_sign_in_limit(): void
    {
        $this->maria();
        $ip = ['REMOTE_ADDR' => '203.0.113.20'];

        Mail::fake();
        $this->withServerVariables($ip)->postJson('/api/v1/forgot-password', ['email' => 'maria@example.com'])->assertOk();
        foreach (range(1, 4) as $i) {
            $this->withServerVariables($ip)->postJson('/api/v1/verify-reset-code', ['email' => 'maria@example.com', 'code' => '000000']);
        }
        foreach (range(1, 6) as $i) {
            $this->withServerVariables($ip)->postJson('/api/v1/register', ['email' => "new{$i}@example.com", 'password' => 'x', 'terms_accepted' => true]);
        }

        // Eleven requests on the old shared counter: this was a 429.
        $this->withServerVariables($ip)->postJson('/api/v1/login', ['email' => 'maria@example.com', 'password' => 'Old!Passw0rd'])
            ->assertOk();
    }

    /*
        Finding 3. A refusal says how long to wait, so the app can show it
        instead of Laravel's bare "Too Many Attempts.".
    */
    #[Test]
    public function finding_3_a_refused_request_says_how_long_to_wait(): void
    {
        $ip = ['REMOTE_ADDR' => '203.0.113.30'];
        $last = null;
        foreach (range(1, 21) as $i) {
            $last = $this->withServerVariables($ip)->postJson('/api/v1/login', ['email' => "x{$i}@example.com", 'password' => 'wrong-pass-1']);
        }

        $last->assertStatus(429)
            ->assertJsonPath('success', false)
            ->assertJsonPath('data.retry_after', fn ($s) => is_int($s) && $s > 0 && $s <= 60)
            ->assertJsonPath('message', fn ($m) => str_starts_with($m, 'Too many tries. Please wait'));
    }

    /*
        Finding 4. Signing up with a phone accepted any digits - "1" made an
        account - while only the app checked the Philippine mobile format.
        A number typed any way is stored the way the app signs in with it.
    */
    #[Test]
    public function finding_4_sign_up_checks_the_phone_number_on_the_server(): void
    {
        foreach (['1', '12345', '0917123', '+1415555012345'] as $bad) {
            $this->postJson('/api/v1/register', ['email' => $bad, 'password' => 'Str0ng!Passw0rd', 'password_confirmation' => 'Str0ng!Passw0rd', 'terms_accepted' => true])
                ->assertStatus(422);
        }
        $this->assertDatabaseCount('users', 0);

        $this->postJson('/api/v1/register', ['email' => '09171234567', 'password' => 'Str0ng!Passw0rd', 'password_confirmation' => 'Str0ng!Passw0rd', 'terms_accepted' => true])
            ->assertCreated();
        $this->assertSame('+639171234567', User::sole()->phone);

        // The same number typed the app's way is the same account.
        $this->postJson('/api/v1/login', ['email' => '+639171234567', 'password' => 'Str0ng!Passw0rd'])->assertOk();
        $this->postJson('/api/v1/register', ['email' => '+63 917 123 4567', 'password' => 'Str0ng!Passw0rd', 'password_confirmation' => 'Str0ng!Passw0rd', 'terms_accepted' => true])
            ->assertStatus(422);
    }

    /*
        Finding 5. The job feed and worker browse loaded every live row and
        scored each in PHP on every request. They now score at most
        kaya.feed.max_candidates rows: the boosted and newest jobs, the most
        recently updated workers.
    */
    #[Test]
    public function finding_5_the_job_feed_scores_a_bounded_number_of_jobs(): void
    {
        config(['kaya.feed.max_candidates' => 3]);
        $employer = User::factory()->create();
        \App\Models\EmployerProfile::create(['user_id' => $employer->id]);
        $category = \App\Models\Category::firstOrCreate(['name' => 'Electrical']);
        foreach (range(1, 5) as $i) {
            \App\Models\JobPost::create([
                'employer_id' => $employer->id, 'category_id' => $category->id, 'title' => "Job {$i}",
                'description' => 'Work.', 'location' => 'Urdaneta City', 'status' => 'open',
                'budget_period' => 'daily', 'expires_at' => now()->addDays(7),
            ])->forceFill(['created_at' => now()->subMinutes(10 - $i)])->save();
        }
        $worker = User::factory()->create();
        \App\Models\WorkerProfile::create(['user_id' => $worker->id, 'category_id' => $category->id]);

        // Nearest-first, as the home screen asks on every load: the ranked path.
        $res = $this->actingAs($worker, 'sanctum')->getJson('/api/v1/jobs?sort=nearest')->assertOk();
        $titles = collect($res->json('data.data'))->pluck('title')->all();

        $this->assertCount(3, $titles);
        $this->assertEqualsCanonicalizing(['Job 3', 'Job 4', 'Job 5'], $titles, 'the newest are the ones kept');
    }

    #[Test]
    public function finding_5_worker_browse_scores_a_bounded_number_of_workers(): void
    {
        $category = \App\Models\Category::firstOrCreate(['name' => 'Masonry']);
        foreach (range(1, 4) as $i) {
            $u = User::factory()->create(['name' => "Worker {$i}"]);
            // A trade, a skill and a town: what being listed takes.
            $p = \App\Models\WorkerProfile::create(['user_id' => $u->id, 'category_id' => $category->id, 'location' => 'Urdaneta City']);
            \App\Models\WorkerSkill::create(['user_id' => $u->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);
            $p->forceFill(['updated_at' => now()->subMinutes(10 - $i)])->save();
        }
        $viewer = User::factory()->create();
        $names = fn () => collect($this->actingAs($viewer, 'sanctum')->getJson('/api/v1/workers')->assertOk()->json('data.data'))->pluck('name')->all();

        // All four are listed - so the cap below is tested on something real.
        config(['kaya.feed.max_candidates' => 500]);
        $this->assertCount(4, $names());

        config(['kaya.feed.max_candidates' => 2]);
        $this->assertEqualsCanonicalizing(['Worker 3', 'Worker 4'], $names(), 'the most recently updated are the ones kept');
    }

    /*
        Finding 6. A post's comments, a worker's applications and saved
        jobs came back whole, however many there were. Each now returns the
        newest kaya.feed.list_limit rows; comments still read oldest first.
    */
    #[Test]
    public function finding_6_a_flooded_post_returns_only_its_newest_comments(): void
    {
        config(['kaya.feed.list_limit' => 3]);
        $post = \App\Models\CommunityPost::create([
            'user_id' => User::factory()->create()->id, 'type' => \App\Models\CommunityPost::TYPE_WORKER,
            'title' => 'Mason, free this week', 'body' => 'Hollow blocks.', 'status' => 'live', 'expires_at' => now()->addDays(7),
        ]);
        $commenter = User::factory()->create();
        foreach (range(1, 5) as $i) {
            \App\Models\CommunityComment::create([
                'community_post_id' => $post->id, 'user_id' => $commenter->id, 'body' => "Comment {$i}",
                'status' => 'live', 'checked_at' => now(),
            ]);
        }

        $bodies = collect($this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson("/api/v1/community/{$post->id}/comments")->assertOk()->json('data'))->pluck('body')->all();

        $this->assertSame(['Comment 3', 'Comment 4', 'Comment 5'], $bodies);
    }

    #[Test]
    public function finding_6_applications_and_saved_jobs_are_bounded(): void
    {
        config(['kaya.feed.list_limit' => 3]);
        $employer = User::factory()->create();
        \App\Models\EmployerProfile::create(['user_id' => $employer->id]);
        $category = \App\Models\Category::firstOrCreate(['name' => 'Electrical']);
        $worker = User::factory()->create();
        \App\Models\WorkerProfile::create(['user_id' => $worker->id, 'category_id' => $category->id]);
        foreach (range(1, 5) as $i) {
            $job = \App\Models\JobPost::create([
                'employer_id' => $employer->id, 'category_id' => $category->id, 'title' => "Job {$i}",
                'description' => 'Work.', 'location' => 'Urdaneta City', 'status' => 'open', 'budget_period' => 'daily',
                'expires_at' => now()->addDays(7),
            ]);
            \App\Models\Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending'])
                ->forceFill(['created_at' => now()->subMinutes(10 - $i)])->save();
            \Illuminate\Support\Facades\DB::table('saved_jobs')->insert(['worker_id' => $worker->id, 'job_id' => $job->id, 'created_at' => now()->subMinutes(10 - $i), 'updated_at' => now()]);
        }

        $this->assertCount(3, $this->actingAs($worker, 'sanctum')->getJson('/api/v1/my-applications')->assertOk()->json('data'));
        $this->assertCount(3, $this->actingAs($worker, 'sanctum')->getJson('/api/v1/saved-jobs')->assertOk()->json('data'));
    }

    /*
        Finding 7. PATCH /jobs/{job}/status wrote any listed status, so a
        completed job could be set back to open and reappear in the feed,
        and an open job could be put in progress with nobody hired. The app
        only ever sends completed and closed.
    */
    #[Test]
    public function finding_7_a_finished_job_cannot_be_reopened_or_skipped_ahead(): void
    {
        $employer = User::factory()->create();
        \App\Models\EmployerProfile::create(['user_id' => $employer->id]);
        $category = \App\Models\Category::firstOrCreate(['name' => 'Electrical']);
        $make = fn (string $status) => \App\Models\JobPost::create([
            'employer_id' => $employer->id, 'category_id' => $category->id, 'title' => "A {$status} job",
            'description' => 'Work.', 'location' => 'Urdaneta City', 'status' => $status, 'budget_period' => 'daily',
            'expires_at' => now()->addDays(7),
        ]);

        $done = $make('completed');
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/jobs/{$done->id}/status", ['status' => 'open'])->assertStatus(422);
        $this->assertSame('completed', $done->fresh()->status);

        $open = $make('open');
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/jobs/{$open->id}/status", ['status' => 'in_progress'])->assertStatus(422);
        $this->assertSame('open', $open->fresh()->status);

        // What the app does still works.
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/jobs/{$open->id}/status", ['status' => 'closed'])->assertOk();
    }

    /*
        Finding 10. One limit of 120 a minute covered everything a signed-in
        person's phone does. An open chat alone polls about 34 times a
        minute (messages every 3s, notifications every 5s, the suspension
        check every 30s) before any screen loads, and the hire service and a
        second phone share the same count. Ordinary use must not be refused.
    */
    #[Test]
    public function finding_10_a_busy_signed_in_minute_is_not_refused(): void
    {
        $maria = $this->maria();

        $statuses = [];
        foreach (range(1, 130) as $i) {
            $statuses[] = $this->actingAs($maria, 'sanctum')->getJson('/api/v1/me')->status();
        }

        $this->assertNotContains(429, $statuses);
    }

    #[Test]
    public function finding_1_a_new_code_starts_with_fresh_tries_and_still_works(): void
    {
        $this->maria();
        $first = $this->resetCode();
        foreach (range(1, 3) as $i) {
            $this->postJson('/api/v1/verify-reset-code', ['email' => 'maria@example.com', 'code' => $this->wrong($first)])->assertStatus(422);
        }

        $this->travel(61)->seconds();
        $second = $this->resetCode();

        $this->postJson('/api/v1/verify-reset-code', ['email' => 'maria@example.com', 'code' => $second])->assertOk();
    }
}
