<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The analytics page has to survive an empty database, and its income and
 * forecast have to come from real rows.
 *
 * A Chart.js canvas with no data still renders axes and gridlines, which reads
 * as a broken chart rather than an empty one.
 */
class VizCheckTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    /** A paid top-up at a package priced in pesos, the way grantFree records it: zero charged. */
    private function paidTopup(int $pesos, \DateTimeInterface $at): void
    {
        $package = DB::table('credit_packages')->insertGetId([
            'name' => 'P' . uniqid(), 'credits' => 50, 'amount_centavos' => $pesos * 100,
            'audience' => 'all', 'is_active' => 1, 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('credit_payments')->insert([
            'user_id' => User::factory()->create()->id, 'reference' => uniqid('r', true), 'credit_package_id' => $package,
            'credits' => 50, 'amount_centavos' => 0, 'status' => 'paid', 'provider_session_id' => uniqid('s', true),
            'paid_at' => $at, 'created_at' => $at, 'updated_at' => $at,
        ]);
    }

    #[Test]
    public function an_empty_database_renders_words_rather_than_empty_grids(): void
    {
        $html = $this->actingAs($this->admin())->get('/admin/analytics')->assertOk()->getContent();

        // The two time charts always exist; their empty state is applied in JS.
        foreach (['incomeChart', 'activityChart'] as $id) {
            $this->assertStringContainsString('id="' . $id . '"', $html, "missing $id");
        }

        // The rest decide server-side, so nothing is drawn over no data.
        $this->assertStringContainsString('No accounts yet', $html);
        $this->assertStringContainsString('No Barya spent in this period', $html);
        $this->assertSame(2, substr_count($html, 'No jobs posted in this period'), 'funnel and trades');
        $this->assertStringNotContainsString('id="spentChart"', $html);
        $this->assertStringNotContainsString('id="tradesChart"', $html);

        // Every export stays reachable.
        foreach (['exports/users', 'exports/jobs', 'exports/hires', 'exports/verifications',
                  'exports/categories', 'exports/top-workers', 'exports/skill-demand',
                  'exports/applicants'] as $path) {
            $this->assertStringContainsString($path, $html, "missing download $path");
        }

        $this->assertStringNotContainsString('yAxisID', $html, 'no second y-axis');
    }

    #[Test]
    public function income_is_counted_at_package_prices_and_says_so(): void
    {
        // Top-ups are free in testing and record zero; what they are worth is
        // the package's price. Two in the period, one well before it.
        $this->paidTopup(99, now()->subDays(2));
        $this->paidTopup(199, now()->subDays(5));
        $this->paidTopup(49, now()->subDays(50));

        $response = $this->actingAs($this->admin())->get('/admin/analytics?days=30');
        $income = $response->viewData('income');

        $this->assertSame(298, $income['pesos']);
        $this->assertSame(2, $income['topups']);
        $this->assertSame(149, $income['per_topup']);
        $this->assertSame(49, $response->viewData('incomeBefore')['pesos']);
        $response->assertSee('at package prices')->assertSee('₱298', false);

        // The dashboard still makes no income claim of its own.
        $this->assertStringNotContainsString('Platform income', $this->actingAs($this->admin())->get('/admin')->getContent());
    }

    #[Test]
    public function the_forecast_follows_the_trend_and_never_goes_below_zero(): void
    {
        // Rising: ₱100 in week one up to ₱1,200 in the latest week.
        for ($w = 0; $w < 12; $w++) {
            $this->paidTopup(100 * ($w + 1), now()->subDays(83 - $w * 7));
        }

        $f = $this->actingAs($this->admin())->get('/admin/analytics')->viewData('forecast');

        $this->assertCount(12, $f['actual']);
        $this->assertCount(4, $f['projected']);
        $this->assertCount(16, $f['labels']);
        $this->assertSame(array_sum($f['projected']), $f['next']);
        // A straight rise carries on rising.
        $this->assertGreaterThan($f['actual'][11], $f['projected'][0]);
        $this->assertGreaterThan($f['projected'][0], $f['projected'][3]);

        // Falling to nothing projects nothing, not a negative income.
        DB::table('credit_payments')->delete();
        for ($w = 0; $w < 6; $w++) {
            $this->paidTopup(1200 - 200 * $w, now()->subDays(83 - $w * 7));
        }
        $f = $this->actingAs($this->admin())->get('/admin/analytics')->viewData('forecast');
        foreach ($f['projected'] as $week) {
            $this->assertGreaterThanOrEqual(0, $week);
        }
    }

    #[Test]
    public function barya_spent_is_grouped_by_what_it_bought(): void
    {
        $user = User::factory()->create();
        foreach ([['application', -2], ['application', -2], ['invitation', -2], ['rehire_invite', -1], ['boost', -8], ['refund', 2]] as [$reason, $delta]) {
            DB::table('credit_transactions')->insert([
                'user_id' => $user->id, 'delta' => $delta, 'balance_after' => 10, 'reason' => $reason,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        $spent = $this->actingAs($this->admin())->get('/admin/analytics')->viewData('spent');

        // Invites and rehire invites are one use; a refund is not spending.
        $this->assertSame(['Boosts' => 8, 'Applications' => 4, 'Invites' => 3], $spent);
    }
}
