<?php

namespace App\Console\Commands;

use App\Services\HireCancellation;
use Illuminate\Console\Command;

/*
    Cancels hires whose cancel request went unanswered.

    The other side has `cancel_answer_hours` to agree; after that the hire is
    cancelled anyway, with the reason on record. Hourly, because two days is
    the promise and a daily sweep would stretch it to three.
*/
class SettleHireCancellations extends Command
{
    protected $signature = 'kaya:settle-hire-cancellations';

    protected $description = 'Cancel hires whose cancel request the other side did not answer in time';

    public function handle(HireCancellation $cancellations): int
    {
        $this->info($cancellations->settleDue() . ' hire(s) cancelled.');

        return self::SUCCESS;
    }
}
