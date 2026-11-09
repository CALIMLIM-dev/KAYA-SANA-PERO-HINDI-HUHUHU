<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/* Each report button offers the reasons that fit what it reports. */
class ReportReasonsByTypeTest extends TestCase
{
    use RefreshDatabase;

    private function codes(User $user, ?string $type): array
    {
        return collect($this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/report-reasons' . ($type ? "?type={$type}" : ''))
            ->assertOk()->json('data.reasons'))->pluck('code')->all();
    }

    #[Test]
    public function each_button_has_its_own_list(): void
    {
        $user = User::factory()->create();

        $this->assertSame(['fake_review', 'abusive_review', 'not_about_work', 'other'], $this->codes($user, 'review'));
        $this->assertSame(['no_show', 'work_not_done', 'not_paid', 'unsafe_work', 'other'], $this->codes($user, 'application'));
        $this->assertContains('sexual_content', $this->codes($user, 'message'));
        $this->assertNotContains('no_show', $this->codes($user, 'job'));

        // A label of its own where the shared one reads wrong.
        $labels = collect($this->actingAs($user, 'sanctum')->getJson('/api/v1/report-reasons?type=user')->json('data.reasons'))
            ->pluck('label', 'code');
        $this->assertSame('Inappropriate profile', $labels['inappropriate']);
    }

    #[Test]
    public function an_old_app_asking_without_a_type_gets_every_reason(): void
    {
        $user = User::factory()->create();

        $this->assertContains('no_show', $this->codes($user, null));
        $this->assertContains('not_paid', $this->codes($user, null));
    }
}
