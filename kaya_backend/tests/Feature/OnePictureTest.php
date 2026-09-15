<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    One picture per account, and the latest upload is it.

    The account screen, the inbox, chat and the job feed each resolved the
    picture their own way, and the worker photo outranked the employer
    picture everywhere but the feed. Someone who changed their employer
    picture kept seeing the old one.
*/
class OnePictureTest extends TestCase
{
    use RefreshDatabase;

    private function hybrid(?string $avatar, ?string $workerPhoto, ?string $logo): User
    {
        $user = User::factory()->create(['avatar' => $avatar]);
        WorkerProfile::create(['user_id' => $user->id, 'profile_photo_path' => $workerPhoto]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'image_path' => $logo, 'location' => 'x']);

        return $user->fresh();
    }

    #[Test]
    public function the_latest_upload_beats_both_profile_pictures(): void
    {
        $user = $this->hybrid('employer_images/newest.jpg', 'profile_photos/older.jpg', 'employer_images/old-logo.jpg');

        $this->assertStringEndsWith('employer_images/newest.jpg', $user->resolvedAvatarUrl());
    }

    #[Test]
    public function a_google_photo_is_only_a_fallback(): void
    {
        $user = $this->hybrid('https://lh3.googleusercontent.com/a/photo', 'profile_photos/mine.jpg', null);
        $this->assertStringEndsWith('profile_photos/mine.jpg', $user->resolvedAvatarUrl());

        $user = $this->hybrid('https://lh3.googleusercontent.com/a/photo', null, null);
        $this->assertSame('https://lh3.googleusercontent.com/a/photo', $user->resolvedAvatarUrl());
    }

    #[Test]
    public function the_account_endpoint_and_the_feed_agree(): void
    {
        $employer = $this->hybrid('employer_images/newest.jpg', 'profile_photos/older.jpg', null);
        JobPost::create(['employer_id' => $employer->id, 'title' => 'Fix a gate', 'description' => 'x', 'status' => 'open', 'expires_at' => now()->addDays(5)]);

        $this->actingAs($employer, 'sanctum')->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.avatar', fn ($url) => str_ends_with($url, 'employer_images/newest.jpg'));

        $viewer = User::factory()->create();
        $feed = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/jobs')->assertOk()->json('data');
        $jobs = $feed['data'] ?? $feed;
        $this->assertStringEndsWith('employer_images/newest.jpg', $jobs[0]['employer_avatar']);
    }

    #[Test]
    public function changing_the_employer_picture_changes_the_account_picture(): void
    {
        if (! extension_loaded('gd')) {
            $this->markTestSkipped('GD is not loaded; fake images cannot be made.');
        }

        Storage::fake(config('filesystems.media'));
        $user = $this->hybrid('profile_photos/older.jpg', 'profile_photos/older.jpg', null);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/image', ['image' => UploadedFile::fake()->image('new.jpg')])
            ->assertOk();

        $user->refresh();
        $this->assertStringStartsWith('employer_images/', $user->avatar);
        $this->assertSame($user->avatar, $user->employerProfile->image_path);
    }
}
