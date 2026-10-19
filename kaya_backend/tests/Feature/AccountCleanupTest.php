<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Strike;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The clean-up of 19 Oct 2026: names written properly, junk accounts and
    posts deleted for good from the panel, and a limit that says what it
    blocks.
*/
class AccountCleanupTest extends TestCase
{
    use RefreshDatabase;

    private function admin(string $role = 'super'): User
    {
        $user = User::factory()->create(['user_type' => 'admin']);
        $user->forceFill(['admin_role' => $role])->save();

        return $user;
    }

    #[Test]
    public function names_are_capitalised_and_na_means_none(): void
    {
        $user = User::factory()->create([
            'first_name' => 'eddison joed', 'middle_name' => 'N/A', 'last_name' => 'CALIMLIM', 'suffix' => 'n/a',
        ]);
        $this->assertSame('Eddison Joed Calimlim', $user->fresh()->name);
        $this->assertNull($user->fresh()->middle_name);
        $this->assertNull($user->fresh()->suffix);

        $user->update(['middle_name' => 'cruz', 'suffix' => 'jr']);
        $this->assertSame('Eddison Joed C. Calimlim Jr.', $user->fresh()->name);

        // An account with only a one-line name, as from Google.
        $google = User::factory()->create(['name' => 'rosie mac', 'first_name' => null, 'last_name' => null]);
        $this->assertSame('Rosie Mac', $google->fresh()->name);
    }

    #[Test]
    public function an_admin_deletes_a_junk_account_for_good(): void
    {
        $junk = User::factory()->create(['first_name' => 'didhdh', 'last_name' => 'djshdhd']);
        WorkerProfile::create(['user_id' => $junk->id]);
        $job = JobPost::create(['employer_id' => $junk->id, 'category_id' => Category::create(['name' => 'Plumbing'])->id,
            'title' => 'dddddd', 'description' => 'x', 'location' => 'Urdaneta City', 'status' => 'open']);

        $this->actingAs($this->admin())->post("/admin/users/{$junk->id}/delete")
            ->assertRedirect(route('admin.users.index'));

        $this->assertNull(User::find($junk->id), 'gone, not just renamed');
        $this->assertNull(JobPost::find($job->id), 'their posts go with them');
        $this->assertDatabaseHas('admin_actions', ['action' => 'user.delete', 'subject_id' => $junk->id]);
    }

    #[Test]
    public function an_admin_deletes_a_post_that_is_not_a_real_job(): void
    {
        $owner = User::factory()->create();
        $job = JobPost::create(['employer_id' => $owner->id, 'category_id' => Category::create(['name' => 'Plumbing'])->id,
            'title' => 'hehehe', 'description' => 'x', 'location' => 'Urdaneta City', 'status' => 'open']);

        $this->actingAs($this->admin())->post("/admin/jobs/{$job->id}/delete")
            ->assertRedirect(route('admin.jobs.index'));

        $this->assertNull(JobPost::find($job->id));
        $this->assertNotNull(User::find($owner->id), 'the account stays');
    }

    #[Test]
    public function only_the_owner_and_sub_admins_may_delete_and_admins_cannot_be(): void
    {
        $target = User::factory()->create();

        // A missing key sends the admin away, as on every page.
        $this->actingAs($this->admin('moderator'))->post("/admin/users/{$target->id}/delete")->assertRedirect();
        $this->assertNotNull(User::find($target->id));

        $other = $this->admin();
        $this->actingAs($this->admin('sub_admin'))->post("/admin/users/{$other->id}/delete")->assertSessionHasErrors('delete');
        $this->assertNotNull(User::find($other->id));
    }

    #[Test]
    public function a_limit_says_what_it_blocks(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        $strike = Strike::create(['user_id' => $user->id, 'reason_code' => 'no_show', 'action' => 'restriction', 'days' => 3,
            'finding' => 'x', 'ends_at' => now()->addDays(3), 'expires_at' => now()->addDays(90)]);

        $this->assertSame('No Applying or Posting (3 Days)', $strike->actionLabel());

        $this->actingAs($user, 'sanctum')->postJson('/api/v1/community', ['type' => 'worker', 'title' => 'x', 'body' => 'x'])
            ->assertForbidden()
            ->assertJsonPath('message', fn ($m) => str_starts_with($m, "You can't apply or post until"));
    }
}
