<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Who may read a worker's CV.
 *
 * This is the most sensitive file the app stores. A resume carries a phone
 * number, a home address and a full employment history, so getting the rule
 * wrong isn't a bug — it's a bulk personal-data leak, and under RA 10173 that
 * is exactly the harm the law exists to prevent.
 *
 * The rule: the worker themselves, and employers the worker has *applied to*.
 * Applying is the consent. Browsing the worker directory is not.
 */
class ResumeAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    private function workerWithResume(): array
    {
        $worker = User::factory()->create();

        $profile = WorkerProfile::create([
            'user_id'              => $worker->id,
            'resume_path'          => 'resumes/cv.pdf',
            'resume_original_name' => 'Juan_CV.pdf',
            'resume_uploaded_at'   => now(),
        ]);

        Storage::disk('local')->put('resumes/cv.pdf', 'pretend pdf bytes');

        return [$worker, $profile];
    }

    /** @test */
    public function a_worker_can_download_their_own_resume()
    {
        [$worker] = $this->workerWithResume();

        $this->actingAs($worker, 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertOk();
    }

    /** @test */
    public function an_employer_the_worker_applied_to_can_download_it()
    {
        [$worker] = $this->workerWithResume();
        $employer = User::factory()->create();

        $job = JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => 'open',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'pending',
        ]);

        $this->actingAs($employer, 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertOk();
    }

    /** @test */
    public function an_employer_with_no_application_from_this_worker_is_refused()
    {
        // The important case. This account can see the worker in the directory
        // and knows their id — that must not be enough. Otherwise any employer
        // could walk /workers and harvest addresses in bulk.
        [$worker] = $this->workerWithResume();
        $stranger = User::factory()->create();

        JobPost::create([
            'employer_id' => $stranger->id,
            'title'       => 'Unrelated job nobody applied to',
            'description' => 'x',
            'budget_min'  => 100,
            'status'      => 'open',
        ]);

        $this->actingAs($stranger, 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertForbidden();
    }

    /** @test */
    public function another_worker_is_refused()
    {
        [$worker] = $this->workerWithResume();

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertForbidden();
    }

    /** @test */
    public function an_application_to_someone_elses_job_does_not_grant_access()
    {
        // The worker applied — just not to *this* employer. A check that only
        // asked "has this worker applied anywhere?" would wrongly pass here.
        [$worker] = $this->workerWithResume();

        $otherEmployer = User::factory()->create();
        $stranger      = User::factory()->create();

        $job = JobPost::create([
            'employer_id' => $otherEmployer->id,
            'title'       => 'Someone else\'s job',
            'description' => 'x',
            'budget_min'  => 100,
            'status'      => 'open',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'pending',
        ]);

        $this->actingAs($stranger, 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertForbidden();
    }

    /** @test */
    public function a_worker_with_no_resume_returns_404_not_403()
    {
        // Distinguishing "nothing here" from "not allowed" is safe: the
        // absence of a resume is not private information, and conflating the
        // two makes the app impossible to debug.
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        $this->actingAs($worker, 'sanctum')
            ->get("/api/v1/workers/{$worker->id}/resume")
            ->assertNotFound();
    }

    // ── upload / delete ─────────────────────────────────────────────────────

    /** @test */
    public function uploading_stores_the_file_privately_and_records_its_name()
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker/profile/resume', [
                'resume' => UploadedFile::fake()->create('Juan_CV.pdf', 40, 'application/pdf'),
            ])
            ->assertOk()
            ->assertJsonPath('data.has_resume', true)
            ->assertJsonPath('data.file_name', 'Juan_CV.pdf');

        $path = WorkerProfile::where('user_id', $worker->id)->value('resume_path');
        Storage::disk('local')->assertExists($path);
    }

    /** @test */
    public function the_storage_path_is_never_returned_to_the_client()
    {
        // Shipping the path invites someone to try building a URL from it. The
        // download endpoint is the only way in, by design.
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        $response = $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker/profile/resume', [
                'resume' => UploadedFile::fake()->create('cv.pdf', 20, 'application/pdf'),
            ])->assertOk();

        $this->assertStringNotContainsString('resume_path', $response->getContent());
        $this->assertStringNotContainsString('resumes/', $response->getContent());
    }

    /** @test */
    public function replacing_a_resume_deletes_the_old_file()
    {
        // Without this every re-upload leaves an orphan on disk that nothing
        // references and nothing will ever clean up.
        [$worker] = $this->workerWithResume();

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker/profile/resume', [
                'resume' => UploadedFile::fake()->create('new.pdf', 20, 'application/pdf'),
            ])->assertOk();

        Storage::disk('local')->assertMissing('resumes/cv.pdf');
    }

    /** @test */
    public function images_are_rejected()
    {
        // A photo of a CV is unreadable for the employer it is meant for, and
        // allowing images turns this into an arbitrary media upload.
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        // Built with create() rather than image(): fake()->image() needs the GD
        // extension, which isn't installed here, and the mime rule is what is
        // actually under test — not whether PHP can draw a JPEG.
        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker/profile/resume', [
                'resume' => UploadedFile::fake()->create('cv.jpg', 20, 'image/jpeg'),
            ])
            ->assertStatus(422);
    }

    /** @test */
    public function deleting_removes_the_file_and_clears_the_record()
    {
        [$worker] = $this->workerWithResume();

        $this->actingAs($worker, 'sanctum')
            ->deleteJson('/api/v1/worker/profile/resume')
            ->assertOk()
            ->assertJsonPath('data.has_resume', false);

        Storage::disk('local')->assertMissing('resumes/cv.pdf');
        $this->assertNull(WorkerProfile::where('user_id', $worker->id)->value('resume_path'));
    }
}
