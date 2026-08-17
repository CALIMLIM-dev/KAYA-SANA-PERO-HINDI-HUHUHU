<?php

namespace App\Console\Commands;

use App\Services\SuspensionService;
use Illuminate\Console\Command;

/**
 * Lifts temporary suspensions that have run their course.
 *
 * Without this a "7 day suspension" is a permanent one that somebody has to
 * remember to undo by hand, which is a promise the product cannot keep.
 */
class LiftExpiredSuspensions extends Command
{
    protected $signature = 'kaya:lift-expired-suspensions';

    protected $description = 'Reinstate accounts whose temporary suspension has ended';

    public function handle(SuspensionService $suspensions): int
    {
        $lifted = $suspensions->liftExpired();

        $this->info($lifted === 0
            ? 'No suspensions were due to end.'
            : "Reinstated {$lifted} account(s).");

        return self::SUCCESS;
    }
}
