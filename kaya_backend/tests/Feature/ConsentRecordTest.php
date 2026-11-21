<?php

namespace Tests\Feature;

use App\Http\Middleware\RecordConsent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The consent box ticked before a sensitive upload is recorded, with the
    Terms version, and only when the upload went through.
*/
class ConsentRecordTest extends TestCase
{
    use RefreshDatabase;

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user);

        return $user;
    }

    #[Test]
    public function a_certificate_sent_with_consent_is_recorded_with_the_terms_version(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker/certifications', [
            'certification_name' => 'NC II Electrical',
            'issuing_organization' => 'TESDA',
            'consent' => '1',
        ])->assertSuccessful();

        $row = DB::table('consents')->where('user_id', $worker->id)->first();
        $this->assertNotNull($row);
        $this->assertSame('certification', $row->subject);
        $this->assertSame(RecordConsent::termsVersion(), $row->terms_version);
        $this->assertNotSame('unknown', $row->terms_version);
    }

    #[Test]
    public function nothing_is_recorded_without_the_tick_or_when_the_upload_fails(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker/licenses', [
            'license_name' => 'Driver', 'issuing_authority' => 'LTO',
        ]);
        // Refused: no name.
        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker/certifications', [
            'issuing_organization' => 'TESDA', 'consent' => '1',
        ])->assertStatus(422);

        $this->assertSame(0, DB::table('consents')->count());
    }
}
