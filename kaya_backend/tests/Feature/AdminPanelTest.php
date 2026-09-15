<?php

namespace Tests\Feature;

use App\Models\AdminAction;
use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The admin panel's newer pages: the ORUS TIN check, the audit log, jobs,
    Barya, categories and announcements.
*/
class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    private function company(?string $tin = '123456789'): User
    {
        $user = User::factory()->create();
        EmployerProfile::create([
            'user_id' => $user->id, 'employer_type' => 'company', 'company_name' => 'Acme Builders',
            'tin' => $tin, 'location' => 'Urdaneta City', 'setup_completed' => true,
        ]);

        return $user;
    }

    private function businessDoc(User $user): Verification
    {
        return Verification::create([
            'user_id' => $user->id, 'document_type' => 'business_reg',
            'document_front_url' => 'x/dti.pdf', 'status' => 'pending',
        ]);
    }

    // ── TIN check on ORUS ────────────────────────────────────────────────────

    #[Test]
    public function a_company_business_document_cannot_be_approved_without_the_orus_tick(): void
    {
        $doc = $this->businessDoc($this->company());

        $this->actingAs($this->admin())
            ->post("/admin/verifications/{$doc->id}/approve")
            ->assertSessionHas('error');

        $this->assertSame('pending', $doc->fresh()->status);
        $this->assertNull($doc->user->employerProfile->fresh()->tin_verified_at);
    }

    #[Test]
    public function the_tick_stamps_who_checked_the_tin_and_when(): void
    {
        $admin = $this->admin();
        $doc = $this->businessDoc($this->company());

        $this->actingAs($admin)
            ->post("/admin/verifications/{$doc->id}/approve", ['tin_checked' => '1'])
            ->assertSessionHas('success');

        $profile = $doc->user->employerProfile->fresh();
        $this->assertSame('verified', $doc->fresh()->status);
        $this->assertNotNull($profile->tin_verified_at);
        $this->assertSame($admin->id, $profile->tin_verified_by);

        $this->assertDatabaseHas('admin_actions', [
            'admin_id' => $admin->id, 'action' => 'verification.approved', 'subject_id' => $doc->id,
        ]);
    }

    #[Test]
    public function a_government_id_needs_no_tick(): void
    {
        $user = $this->company();
        $doc = Verification::create([
            'user_id' => $user->id, 'document_type' => 'government_id', 'id_type' => 'PhilSys',
            'document_front_url' => 'x/id.jpg', 'status' => 'pending',
        ]);

        $this->actingAs($this->admin())
            ->post("/admin/verifications/{$doc->id}/approve")
            ->assertSessionHas('success');

        $this->assertSame('verified', $doc->fresh()->status);
    }

    #[Test]
    public function the_verification_page_shows_the_tin_in_full_with_the_orus_link(): void
    {
        $doc = $this->businessDoc($this->company('123456789'));

        $this->actingAs($this->admin())
            ->get("/admin/verifications/{$doc->id}")
            ->assertOk()
            ->assertSee('123456789')
            ->assertSee('Acme Builders')
            ->assertSee('https://orus.bir.gov.ph')
            ->assertSee('tin_checked');
    }

    #[Test]
    public function the_api_tells_the_owner_their_tin_was_checked(): void
    {
        $user = $this->company();
        $user->employerProfile->forceFill(['tin_verified_at' => now()])->save();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/employer-profile')
            ->assertOk()
            ->assertJsonPath('data.profile.tin_verified', true)
            ->assertJsonMissingPath('data.profile.tin');
    }

    // ── Audit log ────────────────────────────────────────────────────────────

    #[Test]
    public function rejecting_and_suspending_are_written_to_the_log(): void
    {
        $admin = $this->admin();
        $user = $this->company();
        $doc = $this->businessDoc($user);

        $this->actingAs($admin)->post("/admin/verifications/{$doc->id}/reject", ['reason' => 'Blurry scan']);
        $this->actingAs($admin)->post("/admin/users/{$user->id}/suspend", [
            'reason_code' => 'fraud', 'duration' => '7',
        ]);
        $this->actingAs($admin)->post("/admin/users/{$user->id}/activate");

        $this->assertSame(
            ['user.reinstated', 'user.suspended', 'verification.rejected'],
            AdminAction::latest('id')->pluck('action')->all(),
        );

        $this->actingAs($admin)->get('/admin/audit')
            ->assertOk()
            ->assertSee('Blurry scan')
            ->assertSee('Suspended ' . $user->name);
    }

    // ── Jobs ─────────────────────────────────────────────────────────────────

    #[Test]
    public function closing_a_post_refunds_pending_applicants_and_tells_both_sides(): void
    {
        $ledger = app(CreditLedger::class);
        $employer = $this->company();
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id, 'setup_completed' => true]);
        $ledger->credit($worker, 10, CreditTransaction::REASON_LAUNCH_GRANT);

        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix a gate', 'description' => 'x',
            'status' => 'open', 'expires_at' => now()->addDays(5),
        ]);

        $charge = $ledger->charge($worker, 2, CreditTransaction::REASON_APPLICATION, fn ($line) => $line, 'job', $job->id);
        $application = Application::create([
            'job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending',
            'credit_transaction_id' => $charge->id,
        ]);

        $this->actingAs($this->admin())
            ->post("/admin/jobs/{$job->id}/close", ['reason' => 'Asks for a deposit'])
            ->assertSessionHas('success');

        $this->assertSame('closed', $job->fresh()->status);
        $this->assertSame('cancelled', $application->fresh()->status);
        $this->assertSame(10, $ledger->balance($worker));

        $this->assertDatabaseHas('user_notifications', ['user_id' => $employer->id, 'type' => 'job.closed']);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $worker->id, 'type' => 'job.closed']);
        $this->assertDatabaseHas('admin_actions', ['action' => 'job.closed', 'subject_id' => $job->id]);
    }

    #[Test]
    public function the_jobs_pages_render(): void
    {
        $job = JobPost::create([
            'employer_id' => $this->company()->id, 'title' => 'Paint a fence', 'description' => 'x', 'status' => 'open',
        ]);

        $this->actingAs($this->admin())->get('/admin/jobs')->assertOk()->assertSee('Paint a fence');
        $this->actingAs($this->admin())->get('/admin/jobs?status=closed')->assertOk()->assertDontSee('Paint a fence');
        $this->actingAs($this->admin())->get("/admin/jobs/{$job->id}")->assertOk()->assertSee('Close this post');
    }

    // ── Barya ────────────────────────────────────────────────────────────────

    #[Test]
    public function an_admin_can_give_and_take_barya_with_a_note(): void
    {
        $ledger = app(CreditLedger::class);
        $admin = $this->admin();
        $user = User::factory()->create();

        $this->actingAs($admin)->post('/admin/credits/adjust', [
            'user_id' => $user->id, 'amount' => 15, 'note' => 'Goodwill after the outage',
        ])->assertSessionHas('success');

        $this->assertSame(15, $ledger->balance($user));

        $this->actingAs($admin)->post('/admin/credits/adjust', [
            'user_id' => $user->id, 'amount' => -5, 'note' => 'Refund reversed',
        ])->assertSessionHas('success');

        $this->assertSame(10, $ledger->balance($user));

        $line = CreditTransaction::where('user_id', $user->id)->latest('id')->first();
        $this->assertSame('admin_adjustment', $line->reason);
        $this->assertSame('Refund reversed', $line->note);
        $this->assertSame($admin->id, $line->actor_id);

        $this->assertSame(2, AdminAction::where('action', 'credits.adjusted')->count());
    }

    #[Test]
    public function taking_more_than_the_balance_is_refused(): void
    {
        $user = User::factory()->create();

        $this->actingAs($this->admin())->post('/admin/credits/adjust', [
            'user_id' => $user->id, 'amount' => -5, 'note' => 'x',
        ])->assertSessionHas('error');

        $this->assertSame(0, app(CreditLedger::class)->balance($user));
        $this->assertSame(0, AdminAction::count());
    }

    #[Test]
    public function the_barya_page_renders(): void
    {
        $user = User::factory()->create(['name' => 'Rosa Dimaculangan']);
        app(CreditLedger::class)->credit($user, 20, CreditTransaction::REASON_LAUNCH_GRANT);

        $this->actingAs($this->admin())->get('/admin/credits')->assertOk()->assertSee('Rosa Dimaculangan');
        $this->actingAs($this->admin())->get("/admin/credits?user={$user->id}")->assertOk()->assertSee('balance 20');
    }

    // ── Categories and skills ────────────────────────────────────────────────

    #[Test]
    public function categories_can_be_added_renamed_switched_off_and_merged(): void
    {
        $admin = $this->admin();
        $plumbing = Category::create(['name' => 'Plumbing', 'icon' => 'build', 'is_active' => true]);
        $dupe = Category::create(['name' => 'Plumbing Services', 'icon' => 'build', 'is_active' => true, 'is_custom' => true]);
        $job = JobPost::create(['employer_id' => $this->company()->id, 'category_id' => $dupe->id, 'title' => 'x', 'description' => 'x', 'status' => 'open']);

        $this->actingAs($admin)->post('/admin/categories', ['name' => 'Welding'])->assertSessionHas('success');
        $this->assertDatabaseHas('categories', ['name' => 'Welding', 'is_active' => true, 'is_custom' => false]);

        $this->actingAs($admin)->post("/admin/categories/{$plumbing->id}", ['name' => 'Plumbing and Pipes']);
        $this->assertSame('Plumbing and Pipes', $plumbing->fresh()->name);

        $this->actingAs($admin)->post("/admin/categories/{$plumbing->id}/toggle");
        $this->assertFalse($plumbing->fresh()->is_active);

        $this->actingAs($admin)->post("/admin/categories/{$dupe->id}/merge", ['into' => $plumbing->id]);
        $this->assertDatabaseMissing('categories', ['id' => $dupe->id]);
        $this->assertSame($plumbing->id, $job->fresh()->category_id);

        $this->assertSame(4, AdminAction::where('action', 'like', 'category.%')->count());
    }

    #[Test]
    public function a_skill_in_use_cannot_be_removed(): void
    {
        $admin = $this->admin();
        $category = Category::create(['name' => 'Carpentry', 'icon' => 'build', 'is_active' => true]);

        $this->actingAs($admin)->post("/admin/categories/{$category->id}/skills", ['name' => 'Framing'])->assertSessionHas('success');
        $skill = Skill::where('name', 'Framing')->firstOrFail();

        $worker = User::factory()->create();
        \App\Models\WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Framing', 'category_id' => $category->id, 'skill_id' => $skill->id]);

        $this->actingAs($admin)->post("/admin/skills/{$skill->id}/delete")->assertSessionHas('error');
        $this->assertDatabaseHas('skills', ['id' => $skill->id]);

        $this->actingAs($admin)->post("/admin/skills/{$skill->id}", ['name' => 'Wall framing']);
        $this->assertSame('Wall framing', $skill->fresh()->name);

        $this->actingAs($admin)->get('/admin/categories')->assertOk()->assertSee('Wall framing');
    }

    // ── Announcements ────────────────────────────────────────────────────────

    #[Test]
    public function an_announcement_reaches_the_chosen_side_and_skips_suspended_accounts(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id, 'setup_completed' => true]);
        $employer = $this->company();
        $suspended = User::factory()->create(['is_suspended' => true]);
        WorkerProfile::create(['user_id' => $suspended->id, 'setup_completed' => true]);

        $this->actingAs($this->admin())->post('/admin/announcements', [
            'audience' => 'worker', 'title' => 'Maintenance tonight', 'body' => 'KAYA will be down from 11 PM to midnight.',
        ])->assertSessionHas('success', 'Sent to 1 person.');

        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $worker->id, 'type' => 'announcement.sent', 'audience' => 'worker', 'title' => 'Maintenance tonight',
        ]);
        $this->assertDatabaseMissing('user_notifications', ['user_id' => $employer->id]);
        $this->assertDatabaseMissing('user_notifications', ['user_id' => $suspended->id]);

        $this->actingAs($this->admin())->get('/admin/announcements')->assertOk()->assertSee('Maintenance tonight');
    }

    #[Test]
    public function everyone_means_both_sides_in_one_notification_each(): void
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id, 'setup_completed' => true]);
        $employer = $this->company();

        $this->actingAs($this->admin())->post('/admin/announcements', [
            'audience' => 'both', 'title' => 'New version', 'body' => 'Update from the store.',
        ]);

        $this->assertSame(2, UserNotification::where('type', 'announcement.sent')->count());
        $this->assertSame(UserNotification::AUDIENCE_BOTH, UserNotification::where('user_id', $worker->id)->value('audience'));
    }

    // ── Dashboard ────────────────────────────────────────────────────────────

    #[Test]
    public function the_dashboard_renders_with_its_queues(): void
    {
        $this->businessDoc($this->company());

        $this->actingAs($this->admin())->get('/admin')
            ->assertOk()
            ->assertSee('Verifications waiting')
            ->assertSee('TINs not checked')
            ->assertSee('On the platform')
            ->assertSee('Admin actions');
    }

    #[Test]
    public function the_pager_is_the_panels_own_and_never_dark(): void
    {
        $employer = $this->company();
        for ($i = 0; $i < 20; $i++) {
            JobPost::create(['employer_id' => $employer->id, 'title' => "Job {$i}", 'description' => 'x', 'status' => 'open']);
        }

        $this->actingAs($this->admin())->get('/admin/jobs')
            ->assertOk()
            ->assertSee('1 to 15 of 20')
            ->assertSee('Next')
            ->assertDontSee('dark:');
    }

    /*
        A company has no worker profile, and the user page only listed
        verifications under the worker block, so its business document was
        nowhere on its own page. A PDF was also drawn in an img tag.
    */
    #[Test]
    public function a_company_accounts_business_document_shows_on_its_page(): void
    {
        $company = $this->company();
        $doc = $this->businessDoc($company);

        $this->actingAs($this->admin())->get("/admin/users/{$company->id}")
            ->assertOk()
            ->assertSee('Business reg')
            ->assertSee('Open document (PDF)')
            ->assertSee(route('admin.verifications.show', $doc));

        $this->actingAs($this->admin())->get("/admin/verifications/{$doc->id}")
            ->assertOk()
            ->assertSee('Open document')
            ->assertDontSee('<img src="' . route('admin.verifications.document', [$doc, 'front']), false);
    }

    #[Test]
    public function a_regular_user_cannot_open_any_of_it(): void
    {
        $user = User::factory()->create();

        foreach (['/admin/jobs', '/admin/credits', '/admin/categories', '/admin/announcements', '/admin/audit'] as $path) {
            $this->actingAs($user)->get($path)->assertRedirect();
        }
    }
}
