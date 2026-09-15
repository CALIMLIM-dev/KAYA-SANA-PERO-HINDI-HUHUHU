<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The stamp the admin layout polls. It has to move when something an
    admin page shows changes, hold still when nothing does, and carry the
    queue counts for the sidebar.
*/
class AdminPulseTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    #[Test]
    public function the_stamp_moves_when_a_verification_comes_in_and_the_queue_is_counted(): void
    {
        $admin = $this->admin();

        $first = $this->actingAs($admin)->get('/admin/pulse')->assertOk()->json();
        $again = $this->actingAs($admin)->get('/admin/pulse')->json();

        $this->assertSame($first['stamp'], $again['stamp'], 'Nothing changed, so the stamp must not.');
        $this->assertSame(0, $first['queues']['verifications']);

        Verification::create([
            'user_id' => User::factory()->create()->id, 'document_type' => 'business_reg',
            'document_front_url' => 'x/dti.pdf', 'status' => 'pending',
        ]);

        $after = $this->actingAs($admin)->get('/admin/pulse')->json();

        $this->assertNotSame($first['stamp'], $after['stamp']);
        $this->assertSame(1, $after['queues']['verifications']);
        $this->assertSame(0, $after['queues']['reports']);
    }

    #[Test]
    public function the_pulse_is_for_admins_only(): void
    {
        $this->actingAs(User::factory()->create())->get('/admin/pulse')->assertRedirect();
    }
}
