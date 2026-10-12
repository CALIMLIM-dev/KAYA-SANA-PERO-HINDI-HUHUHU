<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Editing a post now happens on the Post a Job form, which can replace the
    photos. A file cannot travel in a JSON PUT, so the app sends a multipart
    POST that names itself PUT. These make sure that lands on the update.
*/
class JobEditPhotosTest extends TestCase
{
    use RefreshDatabase;

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'category_id' => Category::create(['name' => 'Plumbing'])->id,
            'title'       => 'Fix the tap',
            'description' => 'Leaking kitchen tap.',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => now()->toDateString(),
            'end_date'    => now()->toDateString(),
            'photos'      => ['job_photos/old.jpg'],
        ]);
    }

    private function employer(): User
    {
        $user = $this->topUp(User::factory()->create(['is_verified' => true]));
        EmployerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    #[Test]
    public function a_post_named_put_reaches_the_update(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);

        $this->actingAs($employer, 'sanctum')
            ->post("/api/v1/jobs/{$job->id}", [
                '_method'     => 'PUT',
                'title'       => 'Fix the kitchen tap',
                'description' => 'Leaking kitchen tap.',
                'category_id' => $job->category_id,
                'location'    => 'Urdaneta City',
            ], ['Accept' => 'application/json'])
            ->assertOk();

        $this->assertSame('Fix the kitchen tap', $job->fresh()->title);
    }

    #[Test]
    public function new_photos_replace_the_old_ones(): void
    {
        if (! function_exists('imagecreatetruecolor')) {
            $this->markTestSkipped('GD is needed to fake an image.');
        }
        Storage::fake(config('filesystems.media'));

        $employer = $this->employer();
        $job = $this->job($employer);

        $this->actingAs($employer, 'sanctum')
            ->post("/api/v1/jobs/{$job->id}", [
                '_method'     => 'PUT',
                'title'       => 'Fix the tap',
                'description' => 'Leaking kitchen tap.',
                'category_id' => $job->category_id,
                'location'    => 'Urdaneta City',
                'photos'      => [UploadedFile::fake()->image('new.jpg')],
            ], ['Accept' => 'application/json'])
            ->assertOk();

        $photos = $job->fresh()->photos;
        $this->assertCount(1, $photos);
        $this->assertNotSame('job_photos/old.jpg', $photos[0]);
    }
}
