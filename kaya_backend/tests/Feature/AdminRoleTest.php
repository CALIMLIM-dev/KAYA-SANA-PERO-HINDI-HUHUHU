<?php

namespace Tests\Feature;

use App\Enums\AdminRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Not every administrator holds every key.

    There was one kind, and it could read a government ID, move somebody's
    Barya, suspend an account and rewrite the category list. Fine while the
    only admin is the person who built it; a problem the moment somebody is
    brought in to clear the verification queue.

    The rule lives on the routes rather than in the controllers, so what is
    worth testing is that following a URL directly is refused - hiding the
    link in the sidebar is decoration and proves nothing.
*/
class AdminRoleTest extends TestCase
{
    use RefreshDatabase;

    private function admin(?AdminRole $role): User
    {
        $user = User::factory()->create(['user_type' => 'admin', 'is_verified' => true]);

        $user->forceFill(['admin_role' => $role?->value])->save();

        return $user;
    }

    #[Test]
    public function a_moderator_reaches_the_queues_but_not_the_money_or_the_settings(): void
    {
        $moderator = $this->admin(AdminRole::MODERATOR);

        foreach (['/admin', '/admin/verifications', '/admin/reports', '/admin/community', '/admin/reviews', '/admin/jobs', '/admin/users'] as $path) {
            $this->actingAs($moderator)->get($path)->assertOk();
        }

        foreach (['/admin/credits', '/admin/settings', '/admin/categories', '/admin/announcements', '/admin/admins'] as $path) {
            $this->actingAs($moderator)->get($path)
                ->assertRedirect(route('admin.dashboard'));
        }
    }

    #[Test]
    public function an_analyst_reads_and_changes_nothing(): void
    {
        $analyst = $this->admin(AdminRole::ANALYST);

        // /admin/exports itself only forwards to analytics; the files are
        // the pages that matter.
        foreach (['/admin', '/admin/analytics', '/admin/exports/users'] as $path) {
            $this->actingAs($analyst)->get($path)->assertOk($path);
        }

        foreach (['/admin/users', '/admin/verifications', '/admin/reports', '/admin/community', '/admin/credits', '/admin/settings'] as $path) {
            $this->actingAs($analyst)->get($path)
                ->assertRedirect(route('admin.dashboard'));
        }

        // And the actions behind those pages, not only the pages.
        $someone = User::factory()->create();

        $this->actingAs($analyst)
            ->post("/admin/users/{$someone->id}/suspend", ['reason' => 'x'])
            ->assertRedirect(route('admin.dashboard'));

        $this->assertFalse($someone->fresh()->is_suspended);
    }

    #[Test]
    public function a_super_admin_reaches_everything(): void
    {
        $super = $this->admin(AdminRole::SUPER);

        foreach ([
            '/admin', '/admin/analytics', '/admin/users', '/admin/verifications',
            '/admin/reports', '/admin/community', '/admin/reviews', '/admin/jobs',
            '/admin/credits', '/admin/categories', '/admin/announcements',
            '/admin/audit', '/admin/settings', '/admin/admins',
        ] as $path) {
            $this->actingAs($super)->get($path)->assertOk();
        }
    }

    #[Test]
    public function an_admin_account_from_before_the_column_keeps_every_key(): void
    {
        // Taking their keys away with a migration would lock whoever runs the
        // panel out of it.
        $legacy = $this->admin(null);

        $this->actingAs($legacy)->get('/admin/settings')->assertOk();
        $this->assertSame(AdminRole::SUPER, $legacy->adminRole());
    }

    #[Test]
    public function only_a_super_admin_hands_out_access_and_never_to_themselves(): void
    {
        $super = $this->admin(AdminRole::SUPER);
        $moderator = $this->admin(AdminRole::MODERATOR);

        $this->actingAs($super)
            ->post("/admin/admins/{$moderator->id}/role", ['admin_role' => 'analyst'])
            ->assertRedirect();

        $this->assertSame(AdminRole::ANALYST, $moderator->fresh()->adminRole());

        // A moderator cannot promote anybody, including themselves.
        $this->actingAs($moderator)
            ->post("/admin/admins/{$moderator->id}/role", ['admin_role' => 'super'])
            ->assertRedirect(route('admin.dashboard'));

        $this->assertSame(AdminRole::ANALYST, $moderator->fresh()->adminRole());

        // Nor does a super admin demote themselves: on a panel with one of
        // them, that click locks everybody out.
        $this->actingAs($super)
            ->post("/admin/admins/{$super->id}/role", ['admin_role' => 'analyst'])
            ->assertSessionHas('error');

        $this->assertSame(AdminRole::SUPER, $super->fresh()->adminRole());
    }
}
