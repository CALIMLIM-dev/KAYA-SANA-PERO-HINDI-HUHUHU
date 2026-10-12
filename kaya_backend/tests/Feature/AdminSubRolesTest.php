<?php

namespace Tests\Feature;

use App\Enums\AdminRole;
use App\Models\AdminAction;
use App\Models\Category;
use App\Models\Skill;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The narrower administrators (decision D3), and making them.

    As in AdminRoleTest, what matters is that following a URL directly is
    refused; the sidebar hiding a link proves nothing.
*/
class AdminSubRolesTest extends TestCase
{
    use RefreshDatabase;

    private function admin(AdminRole $role): User
    {
        $user = User::factory()->create(['user_type' => 'admin', 'is_verified' => true]);
        $user->forceFill(['admin_role' => $role->value])->save();

        return $user;
    }

    private function reaches(User $admin, array $paths): void
    {
        foreach ($paths as $path) {
            $this->actingAs($admin)->get($path)->assertOk($path);
        }
    }

    private function refused(User $admin, array $paths): void
    {
        foreach ($paths as $path) {
            $this->actingAs($admin)->get($path)->assertRedirect(route('admin.dashboard'));
        }
    }

    #[Test]
    public function a_sub_admin_runs_everything_but_the_four_the_owner_keeps(): void
    {
        $sub = $this->admin(AdminRole::SUB_ADMIN);

        $this->reaches($sub, [
            '/admin', '/admin/users', '/admin/verifications', '/admin/reports', '/admin/community',
            '/admin/reviews', '/admin/jobs', '/admin/support', '/admin/credits', '/admin/categories', '/admin/audit',
        ]);
        $this->refused($sub, ['/admin/admins', '/admin/settings', '/admin/announcements', '/admin/banners']);

        $someone = User::factory()->create();
        $this->actingAs($sub)->post('/admin/credits/adjust', ['user_id' => $someone->id, 'amount' => 50, 'note' => 'x'])
            ->assertRedirect(route('admin.dashboard'));

        // Adds and renames the catalogue; does not hide, merge or delete it.
        $plumbing = Category::create(['name' => 'Plumbing', 'icon' => 'build', 'is_active' => true]);
        $dupe = Category::create(['name' => 'Plumbing Services', 'icon' => 'build', 'is_active' => true]);
        $skill = Skill::create(['name' => 'Pipe Repair', 'category_id' => $plumbing->id]);

        $this->actingAs($sub)->post('/admin/categories', ['name' => 'Welding'])->assertSessionHas('success');
        $this->actingAs($sub)->post("/admin/categories/{$plumbing->id}", ['name' => 'Plumbing and Pipes']);
        $this->assertSame('Plumbing and Pipes', $plumbing->fresh()->name);

        $this->actingAs($sub)->post("/admin/categories/{$dupe->id}/merge", ['into' => $plumbing->id])
            ->assertRedirect(route('admin.dashboard'));
        $this->actingAs($sub)->post("/admin/categories/{$plumbing->id}/toggle")->assertRedirect(route('admin.dashboard'));
        $this->actingAs($sub)->post("/admin/skills/{$skill->id}/delete")->assertRedirect(route('admin.dashboard'));

        $this->assertDatabaseHas('categories', ['id' => $dupe->id]);
        $this->assertTrue($plumbing->fresh()->is_active);
        $this->assertDatabaseHas('skills', ['id' => $skill->id]);

        // And the page does not offer them.
        $this->actingAs($sub)->get("/admin/categories?category={$plumbing->id}")
            ->assertOk()
            ->assertDontSee('Hide from the app')
            ->assertDontSee('Merge and delete');
    }

    #[Test]
    public function each_narrow_role_reaches_its_own_queue_and_nothing_else(): void
    {
        $verifier = $this->admin(AdminRole::VERIFIER);
        $this->reaches($verifier, ['/admin', '/admin/verifications']);
        $this->refused($verifier, ['/admin/users', '/admin/reports', '/admin/support', '/admin/credits', '/admin/categories']);

        $agent = $this->admin(AdminRole::SUPPORT_AGENT);
        $this->reaches($agent, ['/admin/support', '/admin/users']);
        $this->refused($agent, ['/admin/verifications', '/admin/reports', '/admin/credits']);

        // Reads accounts, closes none.
        $someone = User::factory()->create();
        $this->actingAs($agent)->post("/admin/users/{$someone->id}/suspend", ['reason' => 'x'])
            ->assertRedirect(route('admin.dashboard'));
        $this->assertFalse($someone->fresh()->is_suspended);

        $content = $this->admin(AdminRole::CONTENT_MODERATOR);
        $this->reaches($content, ['/admin/reports', '/admin/community', '/admin/reviews', '/admin/jobs', '/admin/users']);
        $this->refused($content, ['/admin/verifications', '/admin/support', '/admin/credits']);

        $finance = $this->admin(AdminRole::FINANCE);
        $this->reaches($finance, ['/admin/credits']);
        $this->refused($finance, ['/admin/users', '/admin/reports', '/admin/settings']);
        $this->actingAs($finance)->post('/admin/credits/adjust', ['user_id' => $someone->id, 'amount' => 5, 'note' => 'Testing'])
            ->assertSessionHasNoErrors();
    }

    #[Test]
    public function a_super_admin_makes_an_administrator_whose_password_is_shown_once(): void
    {
        $super = $this->admin(AdminRole::SUPER);

        $this->actingAs($super)->post('/admin/admins', [
            'name' => 'Ana Reyes', 'email' => 'ana@example.ph', 'admin_role' => 'verifier',
        ])->assertRedirect(route('admin.admins.index'))->assertSessionHas('created');

        $created = session('created');
        $ana = User::where('email', 'ana@example.ph')->firstOrFail();

        $this->assertSame('admin', $ana->user_type);
        $this->assertSame(AdminRole::VERIFIER, $ana->adminRole());
        $this->assertTrue($ana->must_change_password);
        $this->assertTrue(Hash::check($created['password'], $ana->password));
        $this->assertSame(16, strlen($created['password']));
        $this->assertDatabaseHas('admin_actions', ['action' => 'admin.created', 'subject_id' => $ana->id, 'admin_id' => $super->id]);

        // Nobody narrower makes administrators.
        $this->actingAs($this->admin(AdminRole::SUB_ADMIN))
            ->post('/admin/admins', ['name' => 'X', 'email' => 'x@example.ph', 'admin_role' => 'super'])
            ->assertRedirect(route('admin.dashboard'));
        $this->assertDatabaseMissing('users', ['email' => 'x@example.ph']);
    }

    #[Test]
    public function a_new_administrator_must_replace_the_generated_password_first(): void
    {
        $ana = $this->admin(AdminRole::VERIFIER);
        $ana->forceFill(['must_change_password' => true, 'password' => Hash::make('Generated123abc')])->save();

        $this->actingAs($ana)->get('/admin/verifications')->assertRedirect(route('admin.password.edit'));
        $this->actingAs($ana)->get('/admin/password')->assertOk()->assertSee('Choose your own password');

        $this->actingAs($ana)->post('/admin/password', [
            'current_password' => 'Generated123abc',
            'password' => 'Kalabasa2026x', 'password_confirmation' => 'Kalabasa2026x',
        ])->assertRedirect(route('admin.dashboard'));

        $this->assertFalse($ana->fresh()->must_change_password);
        $this->actingAs($ana->fresh())->get('/admin/verifications')->assertOk();
    }

    #[Test]
    public function the_console_command_makes_one_and_prints_its_password(): void
    {
        $this->artisan('kaya:make-admin', ['email' => 'Ben@Example.ph', 'role' => 'support_agent', '--name' => 'Ben Santos'])
            ->expectsOutputToContain('Password')
            ->assertSuccessful();

        $ben = User::where('email', 'ben@example.ph')->firstOrFail();
        $this->assertSame(AdminRole::SUPPORT_AGENT, $ben->adminRole());
        $this->assertTrue($ben->must_change_password);
        $this->assertSame(1, AdminAction::where('action', 'admin.created')->count());

        $this->artisan('kaya:make-admin', ['email' => 'ben@example.ph', 'role' => 'verifier'])->assertFailed();
        $this->artisan('kaya:make-admin', ['email' => 'new@example.ph', 'role' => 'janitor'])->assertFailed();
    }
}
