<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\BadgeRewardService;
use Illuminate\Console\Command;

/*
    Pays every badge already earned but never paid for.

    Badges paid nothing until now, so every account on the platform is owed
    for the ones it has. Rewards are settled on the events that earn them
    going forward; this is the one-off for everything that happened before,
    and a safety net if an event is ever missed.

    Safe to run as often as you like - a badge pays once, ever, and the
    unique key on badge_rewards is what guarantees it rather than this.
*/
class PayBadgeRewards extends Command
{
    protected $signature = 'kaya:pay-badge-rewards {--dry-run : Count what is owed and pay nothing}';

    protected $description = 'Pay Barya for badges earned before rewards existed';

    public function handle(BadgeRewardService $rewards): int
    {
        $dry = (bool) $this->option('dry-run');

        if ($dry) {
            $this->warn('Dry run: nothing will be paid.');
        }

        $paid = 0;
        $people = 0;

        User::where('user_type', '!=', 'admin')
            ->where('is_suspended', false)
            ->with(['workerProfile', 'employerProfile'])
            ->chunkById(100, function ($users) use ($rewards, $dry, &$paid, &$people) {
                foreach ($users as $user) {
                    if ($dry) {
                        continue;
                    }

                    $amount = $rewards->settle($user);

                    if ($amount > 0) {
                        $paid += $amount;
                        $people++;
                        $this->line("  {$user->name}: {$amount}");
                    }
                }
            });

        $this->info($dry
            ? 'Dry run finished. Run without --dry-run to pay.'
            : "Paid {$paid} Barya to {$people} " . ($people === 1 ? 'account' : 'accounts') . '.');

        return self::SUCCESS;
    }
}
