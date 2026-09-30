<?php

namespace App\Exceptions;

use Illuminate\Support\Carbon;

/*
    A boost was bought for something that already has one running.

    Its own exception rather than a bare 422 in each controller, for the same
    reason InsufficientCreditsException is: three call sites refuse this and
    the message has to be identical at all three, including the date. A caller
    that forgets to check gets the refusal anyway.
*/
class AlreadyBoostedException extends \RuntimeException
{
    public function __construct(public readonly ?Carbon $until = null)
    {
        parent::__construct(
            $until
                ? 'This is already boosted until ' . $until->format('M j') . '.'
                : 'This is already boosted.'
        );
    }
}
