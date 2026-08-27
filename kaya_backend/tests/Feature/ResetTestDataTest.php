<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\JobPost;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ResetTestDataTest extends TestCase
{
    use RefreshDatabase;

    #[\PHPUnit\Framework\Attributes\Test]
    public function it_wipes_users_and_data_but_keeps_admin(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $worker = User::factory()->create(['user_type' => 'user']);
        $employer = User::factory()->create(['user_type' => 'user']);

        WorkerProfile::create(['user_id' => $worker->id]);
        JobPost::create([
            'employer_id' => $employer->id,
            'title' => 'Test job',
            'description' => 'x',
            'status' => 'open',
        ]);

        $this->artisan('test:reset --force')->assertSuccessful();

        // Admin survives; everyone else and their data is gone.
        $this->assertDatabaseHas('users', ['id' => $admin->id]);
        $this->assertDatabaseMissing('users', ['id' => $worker->id]);
        $this->assertDatabaseMissing('users', ['id' => $employer->id]);
        $this->assertSame(0, WorkerProfile::count());
        $this->assertSame(0, JobPost::count());
    }

    #[\PHPUnit\Framework\Attributes\Test]
    public function it_refuses_when_there_is_no_admin(): void
    {
        User::factory()->create(['user_type' => 'user']);

        $this->artisan('test:reset --force')->assertFailed();

        // Nothing was touched.
        $this->assertSame(1, User::count());
    }
}
