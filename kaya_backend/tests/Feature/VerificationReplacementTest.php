<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Replacing a verification does not lose the one you had.

    Reported from a hybrid account: submit a government ID as a worker, add an
    employer profile, submit there too, and the first one is gone. The two
    sides share one government ID - correctly, it is one person and one
    document - so the second submission replaces the first.

    The replacement was the problem. The old record was deleted before the new
    files were stored, so anything that failed while storing them left the
    account with nothing: no old verification, no new one. On a deployed box
    where the web server owns the storage directory that is not a rare case,
    it is the normal one.
*/
class VerificationReplacementTest extends TestCase
{
    use RefreshDatabase;

    private function submitId(User $user, string $idType = 'UMID')
    {
        return $this->actingAs($user, 'sanctum')->postJson('/api/v1/verifications', [
            'type' => 'government_id',
            'id_type' => $idType,
            'id_photo' => UploadedFile::fake()->create('id.jpg', 64, 'image/jpeg'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 64, 'image/jpeg'),
        ]);
    }

    #[Test]
    public function resubmitting_a_government_id_leaves_exactly_one(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $this->submitId($user, 'UMID')->assertStatus(201);
        $this->submitId($user, 'Passport')->assertStatus(201);

        $this->assertSame(1, Verification::where('user_id', $user->id)->count());

        // And it is the new one, not the old one left behind.
        $this->assertSame('Passport', Verification::first()->id_type);
    }

    #[Test]
    public function a_business_document_does_not_disturb_the_government_id(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $this->submitId($user)->assertStatus(201);

        // The employer side of the same account, verifying something else.
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/verifications', [
            'type' => 'business_reg',
            'document' => UploadedFile::fake()->create('permit.pdf', 64, 'application/pdf'),
        ])->assertStatus(201);

        // Two different documents, so two records. Neither replaces the other.
        $this->assertSame(2, Verification::where('user_id', $user->id)->count());
        $this->assertNotNull(
            Verification::where('user_id', $user->id)
                ->where('document_type', 'government_id')
                ->first(),
            'The government ID was lost when a business document was submitted.',
        );
    }

    /*
        The case that actually bit.

        A rejected upload has to leave the existing verification alone. The
        request fails either way - the point is that failing does not also
        destroy something that was already there and already valid.
    */
    #[Test]
    public function a_rejected_resubmission_keeps_the_existing_verification(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $this->submitId($user, 'UMID')->assertStatus(201);
        $original = Verification::first();

        // A PDF where an image is required: refused by validation, which is the
        // cheapest way to make the second submission fail after the first
        // succeeded.
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/verifications', [
            'type' => 'government_id',
            'id_type' => 'Passport',
            'id_photo' => UploadedFile::fake()->create('id.pdf', 64, 'application/pdf'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 64, 'image/jpeg'),
        ])->assertStatus(422);

        $still = Verification::where('user_id', $user->id)->get();

        $this->assertCount(1, $still, 'The failed submission destroyed the existing verification.');
        $this->assertSame($original->id, $still->first()->id);
        $this->assertSame('UMID', $still->first()->id_type);
    }
}
