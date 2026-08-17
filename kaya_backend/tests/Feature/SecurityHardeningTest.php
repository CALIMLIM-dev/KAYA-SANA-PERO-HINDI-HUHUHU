<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Regression cover for the 12 Aug security audit.
 *
 * Each test names the hole it closes. They are worth more than the fixes: the
 * fixes are one-liners that anyone could undo without noticing.
 */
class SecurityHardeningTest extends TestCase
{
    use RefreshDatabase;

    private function employerWithJob(): array
    {
        $employer = User::factory()->create([
            'email' => 'boss@example.com',
            'phone' => '09171234567',
        ]);

        \DB::table('employer_profiles')->insert([
            'user_id' => $employer->id, 'company_name' => 'Test Co',
            'employer_type' => 'company', 'location' => 'Urdaneta City',
            'setup_completed' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);

        $job = JobPost::create([
            'employer_id' => $employer->id,
            'category_id' => Category::create(['name' => 'Plumbing'])->id,
            'title' => 'Fix a pipe', 'description' => 'x',
            'location' => 'Urdaneta City', 'status' => 'open',
        ]);

        return [$employer, $job];
    }

    // ── S1: suspension ───────────────────────────────────────────────────────

    #[Test]
    public function a_suspended_account_cannot_sign_back_in_with_google(): void
    {
        config(['services.google.client_id' => 'test-client']);

        $user = User::factory()->create(['email' => 'banned@gmail.com']);
        app(\App\Services\SuspensionService::class)->suspend(
            $user, 'fraud', 'permanent', null, User::factory()->create(['user_type' => 'admin'])
        );

        Http::fake(['oauth2.googleapis.com/tokeninfo*' => Http::response([
            'sub' => '1', 'aud' => 'test-client', 'iss' => 'https://accounts.google.com',
            'email' => 'banned@gmail.com', 'email_verified' => 'true', 'exp' => time() + 3600,
        ])]);

        // Suspending deletes their tokens, which is exactly what sent them back
        // to the sign-in screen — where this handed them a fresh one.
        $this->postJson('/api/v1/google-login', ['id_token' => 'valid'])
            ->assertStatus(403)
            ->assertJsonPath('data.is_suspended', true);

        $this->assertSame(0, $user->fresh()->tokens()->count());
    }

    #[Test]
    public function a_suspended_account_holding_a_token_cannot_use_the_api(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user)->getJson('/api/v1/jobs')->assertOk();

        $user->forceFill(['is_suspended' => true, 'suspended_reason' => 'Scam'])->save();

        // The ban was previously checked in three places, so everything else
        // kept working: posting jobs, applying, messaging, uploading.
        $this->actingAs($user->fresh())->getJson('/api/v1/jobs')->assertStatus(403);
        $this->actingAs($user->fresh())->postJson('/api/v1/reports', [])->assertStatus(403);
    }

    #[Test]
    public function a_suspended_account_can_still_read_why_and_sign_out(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['is_suspended' => true, 'suspended_reason' => 'Scam'])->save();

        // Trapping someone in the app with no explanation is its own problem.
        $this->actingAs($user)->getJson('/api/v1/me')->assertStatus(403)
            ->assertJsonPath('data.suspended_reason', 'Scam');
    }

    // ── S2: PII in the job feed ──────────────────────────────────────────────

    #[Test]
    public function the_job_feed_does_not_carry_employer_contact_details(): void
    {
        [$employer] = $this->employerWithJob();

        $employer->forceFill([
            'is_suspended'    => true,
            'suspension_note' => 'Internal: three complaints, do not reinstate.',
        ])->save();

        $body = $this->actingAs(User::factory()->create())
            ->getJson('/api/v1/jobs')->assertOk()->getContent();

        // Paging this to the end used to yield every employer's contact
        // details from a minute-old account.
        $this->assertStringNotContainsString('boss@example.com', $body);
        $this->assertStringNotContainsString('09171234567', $body);
        // The note's own migration says it is not shown even to the user it
        // describes. It was going to everyone.
        $this->assertStringNotContainsString('do not reinstate', $body);
    }

    #[Test]
    public function an_account_still_sees_its_own_email_and_phone(): void
    {
        $user = User::factory()->create(['email' => 'me@example.com', 'phone' => '09170000000']);

        $login = $this->postJson('/api/v1/login', [
            'email' => 'me@example.com', 'password' => 'password',
        ])->assertOk();

        // Hiding these by default must not lock people out of their own data.
        $this->assertSame('me@example.com', $login->json('data.user.email'));
        $this->assertSame('09170000000', $this->actingAs($user)->getJson('/api/v1/me')->json('data.phone'));
    }

    // ── S4: verification documents ───────────────────────────────────────────

    #[Test]
    public function verification_documents_are_stored_privately(): void
    {
        Storage::fake('local');
        Storage::fake('public');

        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/verifications', [
            'type' => 'government_id', 'id_type' => 'UMID',
            'id_photo' => UploadedFile::fake()->create('id.jpg', 64, 'image/jpeg'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 64, 'image/jpeg'),
        ])->assertStatus(201);

        $v = Verification::first();

        // The public disk is served straight off the filesystem by the web
        // server; a national ID paired with a liveness selfie cannot live there.
        Storage::disk('local')->assertExists($v->document_front_url);
        Storage::disk('public')->assertMissing($v->document_front_url);
    }

    #[Test]
    public function only_the_owner_or_an_admin_can_read_a_verification_document(): void
    {
        Storage::fake('local');

        $owner = User::factory()->create();
        $this->actingAs($owner)->postJson('/api/v1/verifications', [
            'type' => 'government_id', 'id_type' => 'UMID',
            'id_photo' => UploadedFile::fake()->create('id.jpg', 64, 'image/jpeg'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 64, 'image/jpeg'),
        ])->assertStatus(201);

        $v = Verification::first();

        $this->actingAs($owner)->get("/api/v1/verifications/{$v->id}/document/front")->assertOk();
        $this->actingAs(User::factory()->create(['user_type' => 'admin']))
            ->get("/api/v1/verifications/{$v->id}/document/front")->assertOk();

        // 404 not 403: a 403 confirms the record exists, which turns this into
        // a way to test whether someone has submitted an ID at all.
        $this->actingAs(User::factory()->create())
            ->get("/api/v1/verifications/{$v->id}/document/front")->assertStatus(404);
    }

    #[Test]
    public function the_verification_type_is_restricted_to_known_values(): void
    {
        $user = User::factory()->create();

        // Free text here also acted as the delete key, so any string created
        // another row the admin queue had to page through.
        $this->actingAs($user)->postJson('/api/v1/verifications', [
            'type' => '../../whatever',
            'document' => UploadedFile::fake()->create('x.jpg', 64, 'image/jpeg'),
        ])->assertStatus(422);
    }

    // ── S5: credentials ──────────────────────────────────────────────────────

    #[Test]
    public function licence_numbers_and_scans_are_not_public(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create([
            'user_id' => $worker->id, 'location' => 'Urdaneta City',
            'category_id' => Category::create(['name' => 'Electrical'])->id,
            'setup_completed' => true,
        ]);
        \DB::table('worker_skills_new')->insert([
            'user_id' => $worker->id, 'skill_name' => 'Wiring',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        \DB::table('worker_licenses')->insert([
            'user_id' => $worker->id, 'license_name' => 'Master Electrician',
            'license_number' => 'PRC-0012345', 'issuing_authority' => 'PRC',
            'document_path' => 'licenses/scan.jpg',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $body = $this->actingAs(User::factory()->create())
            ->getJson("/api/v1/workers/{$worker->id}")->assertOk();

        // A stranger learns the licence exists and who issued it — not the
        // government identifier, and not a link to a scan carrying a date of
        // birth, a signature and a home address.
        $licence = $body->json('data.licenses.0');
        $this->assertSame('Master Electrician', $licence['name']);
        $this->assertStringNotContainsString('PRC-0012345', json_encode($body->json()));
        $this->assertNull($licence['document_url']);
        $this->assertTrue($licence['has_document']);
    }

    // ── S7: job enumeration ──────────────────────────────────────────────────

    #[Test]
    public function a_closed_job_is_not_readable_by_a_stranger(): void
    {
        [$employer, $job] = $this->employerWithJob();
        $job->update(['status' => 'closed']);

        // Walking /jobs/1..N returned every job ever created, any state, with
        // its address line and coordinates.
        $this->actingAs(User::factory()->create())
            ->getJson("/api/v1/jobs/{$job->id}")->assertStatus(404);

        // The owner still needs it from Manage Jobs.
        $this->actingAs($employer)->getJson("/api/v1/jobs/{$job->id}")->assertOk();
    }

    // ── S8: global reference tables ──────────────────────────────────────────

    #[Test]
    public function custom_categories_are_capped_per_account(): void
    {
        $user = User::factory()->create();

        for ($i = 1; $i <= 5; $i++) {
            $this->actingAs($user)->postJson('/api/v1/categories', ['name' => "Trade {$i}"])
                ->assertStatus(201);
        }

        // Every row appears in every user's picker and there is no moderation
        // queue for them, so one account could fill the list for the platform.
        $this->actingAs($user)->postJson('/api/v1/categories', ['name' => 'Trade 6'])
            ->assertStatus(429);
    }

    // ── S9: trilateration ────────────────────────────────────────────────────

    #[Test]
    public function worker_distance_is_bucketed_not_exact(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create([
            'user_id' => $worker->id, 'location' => 'Urdaneta City',
            'category_id' => Category::create(['name' => 'Carpentry'])->id,
            'latitude' => 15.976, 'longitude' => 120.571, 'setup_completed' => true,
        ]);
        \DB::table('worker_skills_new')->insert([
            'user_id' => $worker->id, 'skill_name' => 'Framing',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $employer = User::factory()->create();
        \DB::table('employer_profiles')->insert([
            'user_id' => $employer->id, 'company_name' => 'Co', 'employer_type' => 'company',
            'location' => 'Urdaneta', 'latitude' => 15.990, 'longitude' => 120.590,
            'setup_completed' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);

        $row = $this->actingAs($employer)->getJson('/api/v1/workers')->json('data.data.0');

        /*
            The viewer sets their own coordinates freely, so an exact distance
            read from three chosen positions puts three circles on a map that
            meet at the worker's home. show() withholds latitude and longitude;
            this was handing back the same thing as a derived value.
        */
        $this->assertContains($row['distance_km'], [1, 5, 15, 30, 50, 100]);
        $this->assertNotNull($row['distance_label']);
    }
}
