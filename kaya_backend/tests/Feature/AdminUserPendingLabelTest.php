<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: the admin user list showed "Pending" on people who were not
    even verified - every unverified account, including ones that never sent
    an ID. Pending now means papers are waiting on an admin.
*/
class AdminUserPendingLabelTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    private function sentAnId(User $user): void
    {
        Verification::create([
            'user_id' => $user->id, 'document_type' => 'government_id',
            'document_front_url' => 'x/id.jpg', 'status' => 'pending',
        ]);
    }

    #[Test]
    public function an_account_that_sent_nothing_is_not_verified_rather_than_pending(): void
    {
        $nothing = User::factory()->create(['name' => 'Sent Nothing', 'is_verified' => false]);
        $waiting = User::factory()->create(['name' => 'Sent An Id', 'is_verified' => false]);
        $this->sentAnId($waiting);

        $page = $this->actingAs($this->admin())->get('/admin/users')->assertOk();

        $page->assertSeeInOrder(['Sent An Id', 'Pending review']);
        $page->assertSeeInOrder(['Sent Nothing', 'Not verified']);
    }

    #[Test]
    public function the_pending_filter_lists_only_papers_waiting_on_an_admin(): void
    {
        User::factory()->create(['name' => 'Sent Nothing', 'is_verified' => false]);
        $waiting = User::factory()->create(['name' => 'Sent An Id', 'is_verified' => false]);
        $this->sentAnId($waiting);

        $admin = $this->admin();

        $this->actingAs($admin)->get('/admin/users?status=pending')
            ->assertOk()->assertSee('Sent An Id')->assertDontSee('Sent Nothing');

        $this->actingAs($admin)->get('/admin/users?status=unverified')
            ->assertOk()->assertSee('Sent Nothing')->assertDontSee('Sent An Id');
    }
}
