<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Deleting your own account.

    The password is asked again, the account cannot be deleted mid-hire,
    and afterwards nothing personal is left: the row stays for the ledger
    and the audit log but says nothing about who it was. Open posts close
    and the people waiting on them are paid back. The old login stops
    working and the same email can register again.
*/
class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'password' => Hash::make('secret123'), 'phone' => '09171234567']);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'password' => Hash::make('secret123')]);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);
        WorkerSkill::create(['user_id' => $user->id, 'skill_id' => null, 'skill_name' => 'Masonry']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 20]);

        return $user;
    }

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint a fence', 'description' => 'x',
            'status' => 'open', 'workers_needed' => 1,
            'start_date' => now()->addDays(3)->toDateString(), 'end_date' => now()->addDays(10)->toDateString(),
            'expires_at' => now()->addDays(10)->endOfDay(),
        ]);
    }

    #[Test]
    public function the_password_has_to_be_right(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker)->deleteJson('/api/v1/me', ['password' => 'wrong'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'That password is not right.');

        $this->assertNull($worker->fresh()->deleted_at);
    }

    #[Test]
    public function an_account_mid_hire_cannot_leave(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);
        $job->update(['status' => 'in_progress']);
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);

        $this->actingAs($employer)->deleteJson('/api/v1/me', ['password' => 'secret123'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'You have 1 job with a worker on it. Finish or cancel it first.');

        $this->actingAs($worker)->deleteJson('/api/v1/me', ['password' => 'secret123'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'You are hired on 1 job that is not finished. Finish it first.');
    }

    #[Test]
    public function deleting_strips_the_account_closes_posts_and_pays_applicants_back(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);
        $email = $employer->email;

        Verification::create(['user_id' => $employer->id, 'document_type' => 'government_id', 'document_front_url' => 'x/id.jpg', 'status' => 'pending']);

        // A real application, so there is a charge to refund.
        $this->actingAs($worker)->postJson("/api/v1/jobs/{$job->id}/apply")->assertStatus(201);
        $this->assertSame(18, CreditWallet::where('user_id', $worker->id)->value('balance'));

        $this->actingAs($employer)->deleteJson('/api/v1/me', ['password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('message', 'Your account has been deleted.');

        $gone = $employer->fresh();
        $this->assertNotNull($gone->deleted_at);
        $this->assertSame('Deleted account', $gone->name);
        $this->assertSame("deleted-{$gone->id}@deleted.kaya", $gone->email);
        $this->assertNull($gone->phone);
        $this->assertNull($gone->employerProfile);
        $this->assertSame(0, Verification::where('user_id', $gone->id)->count());
        $this->assertSame(0, $gone->tokens()->count());

        $this->assertSame('closed', $job->fresh()->status);
        $this->assertSame('rejected', Application::where('job_id', $job->id)->value('status'));
        $this->assertSame(20, CreditWallet::where('user_id', $worker->id)->value('balance'));

        // The old sign-in is refused, the password is gone, and the email is
        // free again.
        $this->postJson('/api/v1/login', ['email' => $email, 'password' => 'secret123'])
            ->assertStatus(401);
        $this->assertFalse(Hash::check('secret123', $gone->password));
        $this->assertFalse(User::where('email', $email)->exists());
    }

    #[Test]
    public function a_worker_leaves_with_their_profile_and_pending_applications_gone(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        $this->actingAs($worker)->deleteJson('/api/v1/me', ['password' => 'secret123'])->assertOk();

        $gone = $worker->fresh();
        $this->assertNull($gone->workerProfile);
        $this->assertSame(0, WorkerSkill::where('user_id', $gone->id)->count());
        $this->assertSame('withdrawn', Application::where('worker_id', $gone->id)->value('status'));
    }
}
