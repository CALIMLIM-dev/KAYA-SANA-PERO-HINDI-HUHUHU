<?php

namespace Tests\Feature;

use App\Models\AdminAction;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The badge stands for a paper somebody looked at: an ID for a person, the
    business papers for a company, and neither for the other.
*/
class VerifiedMeansProvedTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake(config('filesystems.documents'));
    }

    private function admin(): User
    {
        $admin = User::factory()->create();
        $admin->forceFill(['user_type' => 'admin'])->save();

        return $admin;
    }

    private function paper(User $user, string $type, string $status = 'pending'): Verification
    {
        Storage::disk(config('filesystems.documents'))->put("verifications/{$user->id}-{$type}.pdf", 'x');

        return Verification::create([
            'user_id' => $user->id, 'document_type' => $type, 'status' => $status,
            'document_front_url' => "verifications/{$user->id}-{$type}.pdf",
        ]);
    }

    /** A company whose papers an administrator approved. */
    private function company(): User
    {
        $user = User::factory()->create();
        $user->forceFill(['is_verified' => false])->save();
        EmployerProfile::create([
            'user_id' => $user->id, 'employer_type' => 'company', 'company_name' => 'Acme', 'tin' => '123456789',
            'industry' => 'Building', 'location' => 'Urdaneta City', 'setup_completed' => true,
        ]);
        $paper = $this->paper($user, 'business_reg');
        $this->actingAs($this->admin())->post(route('admin.verifications.approve', $paper), ['tin_checked' => 1]);
        $this->assertTrue($user->fresh()->is_verified);

        return $user->fresh();
    }

    private function apply(User $user)
    {
        $boss = User::factory()->create();
        EmployerProfile::create(['user_id' => $boss->id, 'employer_type' => 'individual']);
        $job = JobPost::create([
            'employer_id' => $boss->id, 'category_id' => Category::firstOrCreate(['name' => 'General Labour'])->id,
            'title' => 'Job', 'description' => 'x', 'location' => 'Urdaneta City', 'latitude' => 15.9761, 'longitude' => 120.5711,
            'status' => 'open', 'workers_needed' => 1, 'expires_at' => now()->addDays(5),
        ]);

        return $this->actingAs($user->fresh(), 'sanctum')->postJson("/api/v1/jobs/{$job->id}/apply", []);
    }

    #[Test]
    public function a_company_that_removes_its_employer_side_is_not_a_verified_worker(): void
    {
        $user = $this->company();
        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/employer-profile')->assertOk();

        $this->assertFalse($user->fresh()->is_verified);
        $this->assertSame(0, $user->verifications()->count());
        Storage::disk(config('filesystems.documents'))->assertMissing("verifications/{$user->id}-business_reg.pdf");

        $this->seedWorkerProfile($user);
        $this->apply($user)->assertStatus(403)->assertJsonPath('data.needs_verification', true);

        // And it can be a company again: the papers can be sent again.
        $user->workerProfile()->delete();
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'company', 'company_name' => 'Acme', 'tin' => '123456789', 'location' => 'Urdaneta City']);
        $this->actingAs($user->fresh(), 'sanctum')->post('/api/v1/verifications', [
            'type' => 'business_reg', 'document' => UploadedFile::fake()->create('dti.pdf', 40, 'application/pdf'),
        ])->assertStatus(201);
    }

    #[Test]
    public function a_company_that_saves_itself_as_an_individual_is_not_verified_either(): void
    {
        $user = $this->company();
        $user->employerProfile->update(['employer_type' => 'individual']);

        $this->assertFalse($user->fresh()->is_verified);
    }

    #[Test]
    public function an_approved_id_of_their_own_is_kept(): void
    {
        $user = $this->company();
        $this->paper($user, 'government_id', 'verified');
        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/employer-profile')->assertOk();

        $this->assertTrue($user->fresh()->is_verified);
        $this->assertSame(['government_id'], $user->verifications()->pluck('document_type')->all());
    }

    #[Test]
    public function an_individual_removing_the_employer_side_keeps_the_badge(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['is_verified' => true])->save();
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual']);
        $this->paper($user, 'government_id', 'verified');

        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/employer-profile')->assertOk();
        $this->assertTrue($user->fresh()->is_verified);
        $this->assertSame(1, $user->verifications()->count());
    }

    #[Test]
    public function a_business_document_does_not_verify_a_person(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['is_verified' => false])->save();
        $this->seedWorkerProfile($user);

        $this->actingAs($user, 'sanctum')->post('/api/v1/verifications', [
            'type' => 'dti', 'document' => UploadedFile::fake()->create('dti.pdf', 40, 'application/pdf'),
        ])->assertStatus(422);

        // One sent before this was refused.
        $old = $this->paper($user, 'dti');
        $this->actingAs($this->admin())->post(route('admin.verifications.approve', $old))->assertSessionHas('error');
        $this->assertFalse($user->fresh()->is_verified);
        $this->assertSame('pending', $old->fresh()->status);
    }

    #[Test]
    public function an_administrator_can_remove_an_approved_verification(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['is_verified' => true])->save();
        $this->seedWorkerProfile($user);
        $paper = $this->paper($user, 'government_id', 'verified');
        $admin = $this->admin();

        $this->actingAs($admin)->get(route('admin.verifications.show', $paper))->assertOk()->assertSee('Remove Verification');
        $this->actingAs($admin)->post(route('admin.verifications.reject', $paper), ['reason' => 'Approved by mistake'])->assertRedirect();

        $this->assertFalse($user->fresh()->is_verified);
        $this->assertSame('rejected', $paper->fresh()->status);
        $this->assertSame(1, AdminAction::where('action', 'verification.taken_back')->count());
        $this->assertSame('Your verification was removed', UserNotification::where('user_id', $user->id)->where('type', 'verification.rejected')->value('title'));
        $this->apply($user)->assertStatus(403);

        // And they can send another.
        $this->actingAs($user->fresh(), 'sanctum')->post('/api/v1/verifications', [
            'type' => 'government_id', 'id_type' => 'UMID',
            'id_photo' => UploadedFile::fake()->create('a.jpg', 40, 'image/jpeg'), 'selfie_photo' => UploadedFile::fake()->create('b.jpg', 40, 'image/jpeg'),
        ])->assertStatus(201);
    }

    #[Test]
    public function rejecting_a_pending_paper_does_not_touch_a_badge_already_held(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['is_verified' => true])->save();
        $pending = $this->paper($user, 'government_id');

        $this->actingAs($this->admin())->post(route('admin.verifications.reject', $pending), ['reason' => 'Blurry']);
        $this->assertTrue($user->fresh()->is_verified);
    }

    #[Test]
    public function a_phone_number_is_one(): void
    {
        $user = User::factory()->create(['phone' => null]);
        foreach (['abc123', '123', '+1415555012345'] as $bad) {
            $this->actingAs($user, 'sanctum')->patchJson('/api/v1/me', ['phone' => $bad])->assertStatus(422);
        }
        $this->actingAs($user, 'sanctum')->patchJson('/api/v1/me', ['phone' => '0917 123 4567'])->assertOk();
        $this->assertSame('+639171234567', $user->fresh()->phone);

        // The same number written another way is still somebody else's.
        $other = User::factory()->create(['phone' => null]);
        foreach (['09171234567', '+639171234567', '639171234567'] as $same) {
            $this->actingAs($other, 'sanctum')->patchJson('/api/v1/me', ['phone' => $same])->assertStatus(422);
        }
        // Writing their own again does not undo its check.
        $user->forceFill(['phone_verified_at' => now()])->save();
        $this->actingAs($user->fresh(), 'sanctum')->patchJson('/api/v1/me', ['phone' => '09171234567'])->assertOk();
        $this->assertNotNull($user->fresh()->phone_verified_at);
    }
}
