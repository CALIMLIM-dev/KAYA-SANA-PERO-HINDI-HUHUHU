<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/*
    Uploads follow config, not a hardcoded disk name.

    The disk was written literally as 'public' or 'local' at more than twenty
    call sites, so FILESYSTEM_DISK=s3 moved nothing — every file still landed on
    the container filesystem and still died on the next redeploy. The indirection
    through config('filesystems.media') and config('filesystems.documents') is
    what makes the move to object storage an environment change.

    These tests point the two roles at disks that share no name with 'public' or
    'local'. A reintroduced literal therefore writes somewhere these assertions
    are not looking, and the test fails — which is the only way a change like
    this stays done after the person who made it has moved on.

    The second thing under test is the split itself. Media and documents must
    never share a disk: a profile photo is meant to be fetched by URL, and a
    government ID and a resume must never be.
*/
class StorageDiskRoutingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'filesystems.media'     => 'media_under_test',
            'filesystems.documents' => 'documents_under_test',
        ]);

        Storage::fake('media_under_test');
        Storage::fake('documents_under_test');

        // Faked so a stray literal writes somewhere assertable rather than
        // touching the real filesystem.
        Storage::fake('public');
        Storage::fake('local');
    }

    public function test_a_profile_photo_goes_to_the_media_disk(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        $response = $this->actingAs($worker, 'sanctum')->post(
            '/api/v1/worker/profile/photo',
            ['photo' => UploadedFile::fake()->create('me.jpg', 32, 'image/jpeg')]
        );

        $response->assertOk();

        $stored = WorkerProfile::where('user_id', $worker->id)->value('photo_path')
            ?? User::find($worker->id)->avatar;

        $this->assertNotEmpty($stored, 'the upload recorded no path');
        Storage::disk('media_under_test')->assertExists($stored);

        // The literal it replaced.
        Storage::disk('public')->assertMissing($stored);
    }

    public function test_a_resume_goes_to_the_documents_disk_and_never_to_media(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        $response = $this->actingAs($worker, 'sanctum')->post(
            '/api/v1/worker/profile/resume',
            ['resume' => UploadedFile::fake()->create('cv.pdf', 32, 'application/pdf')]
        );

        $response->assertOk();

        $path = WorkerProfile::where('user_id', $worker->id)->value('resume_path');
        $this->assertNotEmpty($path, 'the upload recorded no resume path');

        Storage::disk('documents_under_test')->assertExists($path);

        /*
            The important half. If a resume ever lands on the media disk it
            becomes reachable by URL, and a resume carries a phone number, a home
            address and a full employment history.
        */
        Storage::disk('media_under_test')->assertMissing($path);
        Storage::disk('local')->assertMissing($path);
    }

    public function test_the_two_roles_are_configured_to_separate_disks(): void
    {
        // Guards the config itself rather than a call site: pointing both at the
        // same disk would silently publish every government ID in the system,
        // and every other test here would still pass.
        $this->assertNotSame(
            config('filesystems.media'),
            config('filesystems.documents'),
            'media and documents must not share a disk'
        );
    }
}
