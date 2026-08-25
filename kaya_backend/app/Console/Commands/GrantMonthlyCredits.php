<?php

namespace App\Console\Commands;

use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Console\Command;
use Illuminate\Database\UniqueConstraintViolationException;

/*
    Pays out the free monthly credits.

    The wallet screen tells everyone they get these, so without this command
    the app was making a promise nothing kept — which is worse than not
    offering them, because somebody waits for credits that are never coming.

    This is also the floor the whole pricing design rests on. A worker who runs
    dry and cannot afford to top up stops opening the app, and enough of those
    leaves nobody to hire. The grant is not generosity; it is the supply side
    staying alive.

    Two guards, and the second is the one that matters. The wallet's
    last_grant_period is checked so a rerun does nothing, and the ledger
    carries a unique index on (user_id, grant_period) so even if that check
    were wrong the database refuses a second payment for the same month.

        php artisan kaya:grant-monthly-credits
*/
class GrantMonthlyCredits extends Command
{
    protected $signature = 'kaya:grant-monthly-credits {--dry-run : Show who would be paid without paying them}';

    protected $description = 'Give every eligible account its free credits for this month';

    public function handle(CreditLedger $ledger): int
    {
        $amount = (int) config('kaya.credits.monthly_grant');

        if ($amount < 1) {
            $this->line('  The monthly grant is set to zero. Nothing to do.');

            return self::SUCCESS;
        }

        // 'YYYY-MM', which compares lexicographically, so `<` is the correct
        // test for "has not been paid this month" without any date arithmetic.
        $period = now()->format('Y-m');
        $dryRun = (bool) $this->option('dry-run');

        $granted = 0;
        $skipped = 0;

        /*
            Who gets one.

            An account with at least one profile, because somebody who signed
            up and never set anything up is not participating yet. Not
            suspended — and that has to be checked here rather than relied on,
            since this runs outside HTTP where the not.suspended middleware
            never sees it. Not an admin.

            One grant per ACCOUNT, never per profile: a hybrid holds two
            profiles, and paying per profile would make creating a second one
            worth free money.
        */
        User::query()
            ->where('user_type', '!=', 'admin')
            ->where(function ($q) {
                $q->whereNot('is_suspended', true)->orWhereNull('is_suspended');
            })
            ->where(fn ($q) => $q->whereHas('workerProfile')->orWhereHas('employerProfile'))
            ->chunkById(500, function ($users) use (
                $ledger, $amount, $period, $dryRun, &$granted, &$skipped
            ) {
                foreach ($users as $user) {
                    $wallet = CreditWallet::where('user_id', $user->id)->first();

                    if ($wallet !== null && $wallet->last_grant_period !== null
                        && $wallet->last_grant_period >= $period) {
                        $skipped++;
                        continue;
                    }

                    if ($dryRun) {
                        $granted++;
                        continue;
                    }

                    try {
                        $ledger->credit(
                            user: $user,
                            amount: $amount,
                            reason: CreditTransaction::REASON_MONTHLY_GRANT,
                            grantPeriod: $period,
                            note: 'Free credits for ' . $period,
                        );

                        CreditWallet::where('user_id', $user->id)
                            ->update(['last_grant_period' => $period]);

                        $granted++;
                    } catch (UniqueConstraintViolationException) {
                        // Already paid for this month by an earlier run that
                        // did not finish updating the wallet. Correct outcome.
                        CreditWallet::where('user_id', $user->id)
                            ->update(['last_grant_period' => $period]);
                        $skipped++;
                    }
                }
            });

        $this->line(sprintf(
            '  %s %d account%s %d each for %s. %d already had theirs.',
            $dryRun ? 'Would pay' : 'Paid',
            $granted,
            $granted === 1 ? '' : 's',
            $amount,
            $period,
            $skipped,
        ));

        return self::SUCCESS;
    }
}
