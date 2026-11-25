<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    People left Pending from before a finished job let them go: listed first,
    then refunded once and told.
*/
class RefundWaitingTest extends TestCase
{
    use RefreshDatabase;

    private function stuck(string $status, bool $paid = true): Application
    {
        $job = JobPost::create([
            'employer_id' => User::factory()->create()->id, 'title' => "A {$status} job", 'description' => 'x', 'location' => 'x', 'status' => $status,
            'category_id' => Category::firstOrCreate(['name' => 'Painting'], ['is_active' => true])->id,
        ]);
        $worker = User::factory()->create(['name' => "Waiting on {$status}"]);
        CreditWallet::updateOrCreate(['user_id' => $worker->id], ['balance' => 50]);
        $charge = $paid
            ? app(CreditLedger::class)->charge(user: $worker, amount: 2, reason: CreditTransaction::REASON_APPLICATION, using: fn ($t) => $t)
            : null;

        return Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending', 'credit_transaction_id' => $charge?->id]);
    }

    private function balance(Application $a): int
    {
        return app(CreditLedger::class)->balance(User::find($a->worker_id));
    }

    #[Test]
    public function it_only_lists_them_until_told_to_run(): void
    {
        $a = $this->stuck('completed');

        $this->artisan('kaya:refund-waiting')
            ->expectsOutputToContain('A completed job')
            ->expectsOutputToContain('2 Barya to return')
            ->expectsOutputToContain('1 person on 1 job. Nothing changed.')
            ->assertSuccessful();

        $this->assertSame('pending', $a->fresh()->status);
        $this->assertSame(48, $this->balance($a));
        $this->assertSame(0, UserNotification::count());
    }

    #[Test]
    public function it_refunds_and_tells_each_of_them_once(): void
    {
        $completed = $this->stuck('completed');
        $closed = $this->stuck('closed');
        $free = $this->stuck('expired', paid: false);

        $this->artisan('kaya:refund-waiting', ['--run' => true])
            ->expectsOutputToContain('3 people on 3 jobs. All cancelled and told, 2 refunded.')
            ->assertSuccessful();

        foreach ([$completed, $closed, $free] as $a) {
            $this->assertSame('cancelled', $a->fresh()->status);
            $this->assertSame(50, $this->balance($a));
        }
        $said = fn (Application $a) => UserNotification::where('user_id', $a->worker_id)->pluck('body')->all();
        $this->assertSame(['"A completed job" was completed by somebody else. Your Barya has been returned.'], $said($completed));
        $this->assertSame(['"A closed job" was closed. Your Barya has been returned.'], $said($closed));
        $this->assertSame(['"A expired job" reached its end date.'], $said($free));

        $this->artisan('kaya:refund-waiting', ['--run' => true])->expectsOutputToContain('0 people on 0 jobs')->assertSuccessful();
        $this->assertSame(50, $this->balance($completed));
        $this->assertSame(3, UserNotification::count());
    }

    #[Test]
    public function a_job_still_going_is_left_alone(): void
    {
        $open = $this->stuck('open');
        $full = $this->stuck('in_progress');

        $this->artisan('kaya:refund-waiting', ['--run' => true])->assertSuccessful();

        $this->assertSame('pending', $open->fresh()->status);
        $this->assertSame('pending', $full->fresh()->status);
    }
}
